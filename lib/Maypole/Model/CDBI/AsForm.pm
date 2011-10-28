package Maypole::Model::CDBI::AsForm;
use strict;

=head1 NAME

Maypole::Model:CDBI::AsForm - Produce HTML form elements for database columns

=head1 SYNOPSIS

use Maypole::Model::CDBI::AsForm;

=head1 DESCRIPTION

This module helps to generate HTML forms for creating new database rows
or editing existing rows. It maps column names in a database table to
HTML form elements which fit the schema. Large text fields are turned
into textareas, and fields with a has-a relationship to other
tables are turned into select drop-downs populated with
objects from the joined class.

=cut

use warnings;

use base qw(Exporter Maypole::Model::AsForm);
use Data::Dumper;
use Class::DBI::Plugin::Type ();
use HTML::Element;
use Carp qw/cluck/;

our $OLD_STYLE = 0;
our @EXPORT = 
	qw( 
		to_cgi to_field  foreign_input_delimiter search_inputs unselect_element
		_field_from_how _field_from_relationship _field_from_column
		_to_textarea _to_textfield _to_select  _select_guts
		_to_foreign_inputs _to_enum_select _to_bool_select
		_to_hidden _to_link_hidden _rename_foreign_input _to_readonly
		_options_from_objects _options_from_arrays _options_from_hashes 
		_options_from_array _options_from_hash 
    );

our $VERSION = '2.13';

=head1 METHODS

=head2 to_cgi

(inherited from Maypole::Model::AsForm)

  $self->to_cgi([@columns, $args]); 

This returns a hash mapping all the column names to HTML::Element objects 
representing form widgets.  It takes two opitonal arguments -- a list of 
columns and a hashref of hashes of arguments for each column.  If called with an object like for editing, the inputs will have the object's values.

  $self->to_cgi(); # uses $self->columns;  # most used
  $self->to_cgi(qw/brewery style rating/); # sometimes
  # and on rare occassions this is desireable if you have a lot of fields
  # and dont want to call to_field a bunch of times just to tweak one or 
  # two of them.
  $self->to_cgi(@cols, { brewery => {  
                                      how => 'textfield' # too big for select 
                                    }, 
    style   => { 
    column_nullable => 0, 
    how => 'select', 
    items => ['Ale', 'Lager']
}
});

=head2 to_field($field [, $how][, $args])

(inherited from Maypole::Model::AsForm)

This maps an individual column to a form element. The C<how> argument
can be used to force the field type into any you want. All that you need 
is a method named "_to_$how" in your class. Your class inherits many from
AsForm  already. 

If C<how> is specified but the class cannot call the method it maps to,
then AsForm will issue a warning and the default input will be made. 
You can write your own "_to_$how" methods and AsForm comes with many.
See C<HOW Methods>. You can also pass this argument in $args->{how}.



=head2 search_inputs

  my $cgi = $class->search_inputs ([$args]); # optional $args

Returns hash or hashref of search inputs elements for a class making sure the
inputs are empty of any initial values.
You can specify what columns you want inputs for in
$args->{columns} or
by the method "search_columns". The default is  "display_columns".
If you want to te search on columns in related classes you can do that by
specifying a one element hashref in place of the column name where
the key is the related "column" (has_a or has_many method for example) and
the value is a list ref of columns to search on in the related class.

Example:
  sub  BeerDB::Beer::search_columns {
	 return ( 'name' , 'rating', { brewery => [ 'name', 'location'] } );
  }

  # Now foreign inputs are made for Brewery name and location and the
  # there will be no name clashing and processing can be automated.

=cut


sub search_inputs {
  my ($class, $args) = @_;
  $class = ref $class || $class;
  #my $accssr_class = { $class->accessor_classes };
  my %cgi;

  $args->{columns} ||= $class->can('search_columns') ?[$class->search_columns] : [$class->display_columns];

  foreach my $field ( @{ $args->{columns} } ) {
    my $base_args = {
		     no_hidden_constraints => 1,
		     column_nullable => 1, # empty option on select boxes
		     value  => '',
		    };
    if ( ref $field eq "HASH" ) { # foreign search fields
      my ($accssr, $cols)  = each %$field;
      $base_args->{columns} = $cols;
      unless (  @$cols ) {
	# default to search fields for related
	#$cols =  $accssr_class->{$accssr}->search_columns;
	die ("$class search_fields error: Must specify at least one column to search in the foreign object named '$accssr'");
      }
      my $fcgi  = $class->to_field($accssr, 'foreign_inputs', $base_args);

      # unset the default values for a select box
      foreach (keys %$fcgi) {
	my $el = $fcgi->{$_};
	if ($el->tag eq 'select') {

	  $class->unselect_element($el);
	  my ($first, @content) = $el->content_list;
	  my @fc = $first->content_list;
	  my $val = $first ? $first->attr('value') : undef;  
	  if ($first and (@fc > 0 or (defined $val and $val ne '')) ) {	# something ( $first->attr('value') ne '' or 

	    # push an empty option on stactk
	    $el->unshift_content(HTML::Element->new('option'));
	  }
	}

      }
      $cgi{$accssr} = $fcgi;
      delete $base_args->{columns};
    } else {
      $cgi{$field} = $class->to_field($field, $base_args); #{no_select => $args->{no_select}{$field} });
      my $el = $cgi{$field};
      if ($el->tag eq 'select') {
	$class->unselect_element($el);
	my ($first, @content) = $el->content_list;
	if ($first and $first->content_list) { # something 
	  #(defined $first->attr('value') or $first->attr('value') ne ''))  
	  # push an empty option on stactk
	  $el->unshift_content(HTML::Element->new('option'));
	}
      }
    }
  }
  return \%cgi;
}

=head2 _field_from_how($field, $how,$args)

Returns an input element based the "how" parameter or nothing at all.
Override at will.

=cut

sub _field_from_how {
  my ($self, $field, $how, $args) = @_;
  return unless $how;
  $args ||= {};
  no strict 'refs';
  my $meth = "_to_$how";
  if (not $self->can($meth)) {
    warn "Class can not $meth";
    return;
  }
  return $self->$meth($field, $args);
}


=head2 _field_from_relationship($field, $args)

Returns an input based on the relationship associated with the field or nothing.
Override at will.

For has_a it will give select box

=cut

sub _field_from_relationship {
  my ($self, $field, $args) = @_;
  return unless $field;
  my $rel_meta = $self->related_meta('r',$field) || return; 
  my $rel_name = $rel_meta->{name};
  my $fclass = $rel_meta->foreign_class;
  my $fclass_is_cdbi = $fclass ? $fclass->isa('Class::DBI') : 0;

  # maybe has_a select 
  if ($rel_meta->{name} eq 'has_a' and $fclass_is_cdbi) {
    # This condictions allows for trumping of the has_a args
    if (not $rel_meta->{args}{no_select} and not $args->{no_select}) {
      $args->{class} = $fclass;
      return  $self->_to_select($field, $args);
    }
    return;
  }
  # maybe has many select
  if ($rel_meta->{name} eq 'has_many' and $fclass_is_cdbi and ref $self) {
    # This condictions allows for trumping of the has_a args
    if (not $rel_meta->{args}{no_select} and not $args->{no_select}) {
      $args->{class} = $fclass;
      my @itms = $self->$field; # need list not iterator
      $args->{items} = \@itms;
      return  $self->_to_select($field, $args);
    }
    return;
  }

  # maybe foreign inputs 
  my %local_cols = map { $_ => 1 } $self->columns; # includes is_a cols
  if ($fclass_is_cdbi and (not $local_cols{$field} or $rel_name eq 'has_own')) {
    $args->{related_meta} = $rel_meta; # suspect faster to set these args 
    return $self->_to_foreign_inputs($field, $args);
  }
  return;
}

=head2 _field_from_column($field, $args)

Returns an input based on the column's characteristics, namely type, or nothing.
Override at will.

=cut

sub _field_from_column {
  my ($self, $field, $args) = @_;
  # this class and pk are default class and field at this point
  my $class = $args->{class} || $self;
  $class = ref $class || $class;
  $field  ||= ($class->primary_columns)[0]; # TODO

  # Get column type
  unless ($args->{column_type}) { 
    if ($class->can('column_type')) {
      $args->{column_type} = $class->column_type($field);
    } else {
      # Right, have some of this
      eval "package $class; Class::DBI::Plugin::Type->import()";
      $args->{column_type} = $class->column_type($field);
    }
  }
  my $type = $args->{column_type};

  return $self->_to_textfield($field, $args)
    if $type  and $type =~ /^(VAR)?CHAR/i; #common type
  return $self->_to_textarea($field, $args)
    if $type and $type =~ /^(TEXT|BLOB)$/i;
  return $self->_to_enum_select($field, $args)  
    if $type and  $type =~ /^ENUM\((.*?)\)$/i; 
  return $self->_to_bool_select($field, $args)
    if $type and  $type =~ /^BOOL/i; 
  return $self->_to_readonly($field, $args)
    if $type and $type =~ /^readonly$/i;
  return;
}

# Makes a readonly input box out of column's value
# No args makes object to readonly
sub _to_readonly {
  my ($self, $col, $args) = @_;
  my $val = $args->{value};
  if (not defined $val ) {	# object to readonly
    $self->_croak("AsForm: To readonly field called as class method without a value") unless ref $self; 
    $val = $self->id;
    $col = $self->primary_column;
  }
  my $a = HTML::Element->new('input', 'type' => 'text', readonly => '1',
			     'name' => $col, 'value'=>$val);
  $OLD_STYLE && return $a->as_HTML;
  $a;
}

=head2 _to_hidden($field, $args)

This makes a hidden html element input. It uses the "name" and "value" 
arguments. If one or both are not there, it will look for an object in 
"items->[0]" or the caller. Then it will use $field or the primary key for
name  and the value of the column by the derived name.

=cut

sub _to_hidden {
  my ($self, $field, $args) = @_;
  $args ||= {};
  my ($name, $value) = ($args->{'name'}, $args->{value});
  $name = $field unless defined $name;
  if (! defined $name and !defined $value) { # check for objects
    my $obj = $args->{items}->[0] || $self;
    unless (ref $obj) {
      die "_to_hidden cannot determine a value. It was passed a value argument or items object or called with an object.";
    }
    $name = $obj->primary_column->name unless $name;
    $value = $obj->$name unless $value;
  }

  return HTML::Element->new('input', 'type' => 'hidden',
			    'name' => $name, 'value'=>$value);
}

=head2 _to_link_hidden($col, $args) 

Makes a link with a hidden input with the id of $obj as the value and name.
Name defaults to the objects primary key. The object defaults to self.

=cut

sub _to_link_hidden {
  my ($self, $accessor, $args) = @_;
  my $r =  eval {$self->controller} || $args->{r} || '';
  my $uri = $args->{uri} || '';
  $self->_croak("_to_link_hidden cant get uri. No  Maypole Request class (\$r) or uri arg. Need one or other.")
    unless $r;
  my ($obj, $name);
  if (ref $self) {		# hidding linking self
    $obj  = $self;
    $name = $args->{name} || $obj->primary_column->name;
  } elsif ($obj = $args->{items}->[0]) {
    $name = $args->{name} || $accessor || $obj->primary_column->name; 
    # TODO use meta data above maybe
  } else {	       # hiding linking related object with id in args
    $obj  = $self->related_class($r, $accessor)->retrieve($args->{id});
    $name = $args->{name} || $accessor ; #$obj->primary_column->name;
    # TODO use meta data above maybe
  }
  $self->_croak("_to_link_hidden has no object") unless ref $obj;
  my $href =  $uri || $r->config->{uri_base} . "/". $obj->table."/view/".$obj->id;
  my $a = HTML::Element->new('a', 'href' => $href);
  $a->push_content("$obj");
  $a->push_content($self->to_field('blahfooey', 'hidden', {name => $name, value =>  $obj->id} ));

  $OLD_STYLE && return $a->as_HTML;
  return $a;
}

sub _to_textarea {
  my ($self, $col, $args) = @_;
  my $class = $args->{class} || $self;
  $class = ref $class || $class;
  $col  ||= ($class->primary_columns)[0]; # TODO
  # pjs added default
  $args ||= {};
  my $val =  $args->{value}; 

  unless (defined $val) {
    if (ref $self) {
      $val = $self->$col; 
    } else { 
      $val = $args->{default}; 
      $val = '' unless defined $val;  
    }
  }
  my ($rows, $cols) = $self->_box($val);
  $rows = $args->{rows} if $args->{rows};
  $cols = $args->{cols} if $args->{cols};;
  my $name = $args->{name} || $col; 
  my $a =
    HTML::Element->new("textarea", name => $name, rows => $rows, cols => $cols);
  $a->push_content($val);
  $OLD_STYLE && return $a->as_HTML;
  $a;
}

sub _to_textfield {
  my ($self, $col, $args ) = @_;
  use Carp qw/confess/;
  confess "No col passed to _to_textfield" unless $col;
  $args ||= {};
  my $val  = $args->{value}; 
  my $name = $args->{name} || $col; 

  unless (defined $val) {
    if (ref $self) {
      # Case where column inflates.
      # Input would get stringification which could be not good.
      #  as in the case of Time::Piece objects
      $val = $self->can($col) ? $self->$col : ''; # in case it is a virtual column
      if (ref $val) {
	if (my $meta = $self->related_meta('',$col)) {
	  if (my $code = $meta->{args}{deflate4edit} || $meta->{args}{deflate} ) {
	    $val  = ref $code ? &$code($val) : $val->$code;
	  } elsif ( $val->isa('Class::DBI') ) {
	    $val  = $val->id;
	  } else { 
	    #warn "No deflate4edit code defined for $val of type " . 
	    #ref $val . ". Using the stringified value in textfield..";
	  }
	} else {
	  $val  = $val->id if $val->isa("Class::DBI"); 
	}
      }

    } else {
      $val = $args->{default}; 
      $val = '' unless defined $val;
    }
  }
  my $a;
  # THIS If section is neccessary or you end up with "value" for a vaiue
  # if val is 
  $val = '' unless defined $val; 
  $a = HTML::Element->new("input", type => "text", name => $name, value =>$val);
  $OLD_STYLE && return $a->as_HTML;
  $a;
}

=head2 recognized arguments

  selected => $object|$id,
  name     => $name,
  value    => $value,
  where    => SQL 'WHERE' clause,
  order_by => SQL 'ORDER BY' clause,
  constraint => hash of constraints to search
  limit    => SQL 'LIMIT' clause,
  items    => [ @items_of_same_type_to_select_from ],
  class => $class_we_are_selecting_from
  stringify => $stringify_coderef|$method_name


=head2  1. a select box out of a has_a or has_many related class.
  # For has_a the default behavior is to make a select box of every element in 
  # related class and you choose one. 
  #Or explicitly you can create one and pass options like where and order
  BeerDB::Beer->to_field('brewery','select', {where => "location = 'Germany'");

  # For has_many the default is to get a multiple select box with all objects.
  # If called as an object method, the objects existing ones will be selected. 
  Brewery::BeerDB->to_field('beers','select', {where => "rating > 5"}); 


=head2  2. a select box for objects of arbitrary class -- say BeerDB::Beer for fun. 
  # general 
  BeerDB::Beer->to_field('', 'select', $options)

  BeerDB::Beer->to_field('', 'select'); # Select box of all the rows in class
								  # with PK as ID, $Class->to_field() same.
  BeerDB::Beer->to_field('','select',{ where => "rating > 3 AND class like 'Ale'", order_by => 'rating DESC, beer_id ASC' , limit => 10});
  # specify exact where clause 

=head2 3. If you already have a list of objects to select from  -- 

  BeerDB:;Beer->to_field($col, 'select' , {items => $objects});

# 3. a select box for arbitrary set of objects 
 # Pass array ref of objects as first arg rather than field 
 $any_class_or_obj->to_field([BeerDB::Beer->search(favorite => 1)], 'select',);


=cut

sub _to_select {
  my ($self, $col, $args) = @_;

  $args ||= {};
  # Do we have items already ? Go no further. 
  if ($args->{items} and ref $args->{items}) {  
    my $a = $self->_select_guts($col,  $args);
    $OLD_STYLE && return $a->as_HTML;
    if ($args->{multiple}) {
      $a->attr('multiple', 'multiple');
    }
    return $a;
  }

  # Proceed with work

  my $rel_meta;
  if (not $col) {
    unless ($args->{class}) {
      $args->{class} = ref $self || $self;
      # object selected if called with one
      $args->{selected} = { $self->id => 1} 
	if not $args->{selected} and ref $self;
    }
    $col = $args->{class}->primary_column;
    $args->{name} ||= $col;
  }
  # Related Class maybe ? 
  elsif ($rel_meta =  $self->related_meta('r:)', $col) ) {
    $args->{class} = $rel_meta->{foreign_class};
    # related objects pre selected if object
    # "Has many" -- Issues:
    # 1) want to select one  or many from list if self is an object
    # Thats about all we can do really, 
    # 2) except for mapping which is TODO and  would 
    # do something like add to and take away from list of permissions for
    # example.

    # Hasmany select one from list if ref self
    if ($rel_meta->{name} =~ /has_many/i and ref $self) {
      my @itms =  $self->$col;	# need list not iterator
      $args->{items} = \@itms;
      my $a = $self->_select_guts($col,  $args);
      $OLD_STYLE && return $a->as_HTML;
      return $a;
    } else {
      $args->{selected} ||= [ $self->$col ] if  ref $self; 
      #warn "selected is " . Dumper($args->{selected});
      my $c = $rel_meta->{args}{constraint} || {};
      my $j = $rel_meta->{args}{join} || {};
      my @join ; 
      if (ref $self) {
	@join   =  map { $_ ." = ". $self->_attr($_) } keys %$j; 
      }
      my @constr= map { "$_ = '$c->{$_}'"} keys %$c; 
      $args->{where}    ||= join (' AND ', (@join, @constr));
      $args->{order_by} ||= $rel_meta->{args}{order_by};
      $args->{limit}    ||= $rel_meta->{args}{limit};
    }
  }

  # Set arguments 
  unless ( defined  $args->{column_nullable} ) {
    $args->{column_nullable} = $self->can('column_nullable') ?
      $self->column_nullable($col) : 1;
  }

  # Get items to select from
  my $items = _select_items($args); # array of hashrefs 

  # Turn items into objects if related 
  if ($rel_meta and not $args->{no_construct}) { 
    my @objs = ();
    push @objs, $rel_meta->{foreign_class}->construct($_) foreach @$items;
    $args->{items} = \@objs; 
  } else {
    $args->{items} = $items;
  }

  # Make select HTML element
  $a = $self->_select_guts($col, $args);

  if ($args->{multiple}) {
    $a->attr('multiple', 'multiple');
  }

  # Return 
  $OLD_STYLE && return $a->as_HTML;
  $a;

}

############
# FUNCTION #
############
# Get Items  returns array of hashrefs
sub _select_items { 
  my $args = shift;
  my $fclass = $args->{class};
  my @disp_cols = @{$args->{columns} || []};
  @disp_cols = $fclass->columns('SelectBox') unless @disp_cols;
  @disp_cols = $fclass->columns('Stringify')unless @disp_cols;
  @disp_cols = $fclass->_essential unless @disp_cols;
  unshift @disp_cols,  $fclass->columns('Primary');

  #warn "in select items. args are : " . Dumper($args);
  my $distinct = '';
  if ($args->{'distinct'}) {
    $distinct = 'DISTINCT ';
  }

  my $sql = "SELECT $distinct" . join( ', ', @disp_cols) . 
    " FROM " . $fclass->table;

  $sql .=	" WHERE " . $args->{where}   if $args->{where};
  $sql .= " ORDER BY " . $args->{order_by} if $args->{order_by};
  $sql .= " LIMIT " . $args->{limit} if $args->{limit};
  #warn "_select_items sql is : $sql";

  my $sth = $fclass->db_Main->prepare($sql);
  $sth->execute;
  my @data;
  while ( my $d = $sth->fetchrow_hashref ) {
    push @data, $d;
  }
  return \@data;
}

=head2 _to_foreign_inputs

Creates inputs for a foreign class, usually related to the calling class or 
object. In names them so they do not clash with other names and so they 
can be processed generically.  See _rename_foreign_inputs below  and 
Maypole::Model::CDBI::FromCGI::classify_foreign_inputs.

Arguments this recognizes are :

	related_meta -- if you have this, great, othervise it will determine or die
	columns  -- list of columns to make inputs for 
	request (r) -- TODO the Maypole request so we can see what action  

=cut

sub _to_foreign_inputs {
  my ($self, $accssr, $args) = @_;
  my $rel_meta = $args->{related_meta} || $self->related_meta('r',$accssr); 
  my $fields 		= $args->{columns};
  if (!$rel_meta) {
    $self->_carp( "[_to_foreign_inputs] No relationship for accessor $accssr");
    return;
  }

  my $rel_type = $rel_meta->{name};
  my $classORobj = ref $self && ref $self->$accssr ? $self->$accssr : $rel_meta->{foreign_class};
	
  unless ($fields) { 	
    $fields = $classORobj->can('display_columns') ? 
      [$classORobj->display_columns] : [$classORobj->columns];
  }
	
  # Ignore our fkey in them to  prevent infinite recursion 
  my $me 	        = eval {$rel_meta->{args}{foreign_key}} || 
    eval {$rel_meta->{args}{foreign_column}}
      || '';	   # what uses foreign_column has_many or might_have  
  my $constrained = $rel_meta->{args}{constraint}; 
  my %inputs;
  foreach ( @$fields ) {
    next if $constrained->{$_} || ($_ eq $me); # don't display constrained
    $inputs{$_} =  $classORobj->to_field($_);
  }

  # Make hidden inputs for constrained columns unless we are editing object
  # TODO -- is this right thing to do?
  unless (ref $classORobj || $args->{no_hidden_constraints}) {
    foreach ( keys %$constrained ) {
      $inputs{$_} = $classORobj->to_field('blahfooey', 'hidden', 
					  { name => $_, value => $constrained->{$_}} );
    }
  }
  $self->_rename_foreign_input($accssr, \%inputs);
  return \%inputs;
}


=head2 _hash_selected

*Function* to make sense out of the "selected" argument which has values of the 
options that should be selected by default when making a select box.  It
can be in a number formats.  This method returns a map of which options to 
select with the values being the keys in the map ( {val1 => 1, val2 = 1} ).

Currently this method  handles the following formats for the "selected" argument
and in the following ways

  Object 				-- uses the id method  to get the value
  Scalar 				-- assumes it *is* the value
  Array ref of objects 	-- same as Object
  Arrays of data 		-- uses the 0th element in each
  Hashes of data 		-- uses key named 'id'

=cut

############
# FUNCTION #
############

sub _hash_selected {
  my ($args) = shift;
  my $selected = $args->{value} || $args->{selected};
  my $type = ref $selected;
  return $selected unless $selected and $type ne 'HASH'; 

  # Single Object 
  if ($type and $type ne 'ARRAY') {
    my $id = $selected->id;
    $id =~ s/^0*//;
    return  {$id => 1};
  }
  # Single Scalar id 
  elsif (not $type) {
    return { $selected => 1}; 
  }

  # Array of objs, arrays, hashes, or just scalalrs. 
  elsif ($type eq 'ARRAY') {
    my %hashed;
    my $ltype = ref $selected->[0];
    # Objects
    if ($ltype and $ltype ne 'ARRAY') {
      %hashed = map { $_->id  => 1 } @$selected;
    }
    # Arrays of data with id first 
    elsif ($ltype and $ltype eq 'ARRAY') {
      %hashed = map { $_->[0]  => 1 } @$selected; 
    }
    # Hashes using pk or id key
    elsif ($ltype and $ltype eq 'HASH') {
      my $pk = $args->{class}->primary_column || 'id';
      %hashed = map { $_->{$pk}  => 1 } @$selected; 
    }
    # Just Scalars
    else { 
      %hashed = map { $_  => 1 } @$selected; 
    }
    return \%hashed;
  } else {
    warn "AsForm Could not hash the selected argument: $selected";
  }
  return;
}



=head2 _select_guts 

Internal api  method to make the actual select box form elements. 
the data.

Items to make options out of can be 
  Hash, Array, 
  Array of CDBI objects.
  Array of scalars , 
  Array or  Array refs with cols from class,
  Array of hashes 

=cut

sub _select_guts {
  my ($self, $col, $args) = @_;	#$nullable, $selected_id, $values) = @_;

  $args->{selected} = _hash_selected($args) if defined $args->{selected};
  my $name = $args->{name} || $col;
  my $a = HTML::Element->new('select', name => $name);
  $a->attr( %{$args->{attr}} ) if $args->{attr};
    
  if ($args->{column_nullable}) {
    my $null_element = HTML::Element->new('option', value => '');
    $null_element->attr(selected => 'selected')
      if ($args->{selected}{'null'});
    $a->push_content($null_element);
  }

  my $items = $args->{items};
  my $type = ref $items;
  my $proto = eval { ref $items->[0]; } || "";
  my $optgroups = $args->{optgroups} || '';

  # Array of hashes, one for each optgroup
  if ($optgroups) {
    my $i = 0;
    foreach (@$optgroups) {
      my $ogrp=  HTML::Element->new('optgroup', label => $_);
      $ogrp->push_content($self->_options_from_hash($items->[$i], $args));
      $a->push_content($ogrp);
      $i++;
    }
  }

  # Single Hash
  elsif ($type eq 'HASH') {
    $a->push_content($self->_options_from_hash($items, $args));
  }
  # Single Array
  elsif ( $type eq 'ARRAY' and not ref $items->[0] ) {
    $a->push_content($self->_options_from_array($items, $args));
  }
  # Array of Objects
  elsif ( $type eq 'ARRAY' and $proto !~ /ARRAY|HASH/i ) {
    # make select  of objects
    $a->push_content($self->_options_from_objects($items, $args));
  }
  # Array of Arrays
  elsif ( $type eq 'ARRAY' and $proto eq 'ARRAY' ) {
    $a->push_content($self->_options_from_arrays($items, $args));
  }
  # Array of Hashes
  elsif ( $type eq 'ARRAY' and $proto eq 'HASH' ) {
    $a->push_content($self->_options_from_hashes($items, $args));
  } else {
    die "You passed a weird type of data structure to me. Here it is: " .
      Dumper($items );
  }

  return $a;


}

=head2 _options_from_objects ( $objects, $args);

Private method to makes a options out of  objects. It attempts to call each
objects stringify method specified in $args->{stringify} as the content. Otherwise the default stringification prevails.

*Note only  single primary keys supported

=cut
sub _options_from_objects {
  my ($self, $items, $args) = @_;
  my $selected = $args->{selected} || {};

  my @res;
  for my $object (@$items) {
    my $stringify = $args->{stringify};
    if ($object->can('stringify_column') ) {
      $stringify ||= $object->stringify_column if ($object->stringify_column && $object->can($object->stringify_column));
    }
    my $id = $object->id;
    my $opt = HTML::Element->new("option", value => $id);
    $id =~ s/^0*//;		# leading zeros no good in hash key
    $opt->attr(selected => "selected") if $selected->{$id};
    my $content = $stringify ? $object->$stringify :  "$object";
    $opt->push_content($content);
    push @res, $opt;
  }
  return @res;
}

sub _options_from_arrays {
  my ($self, $items, $args) = @_;
  my $selected = $args->{selected} || {};
  my @res;
  my $class = $args->{class} || '';
  my $stringify = $args->{stringify};
  $stringify ||= $self->stringify_column if ($self->can('stringify_column'));
  for my $item (@$items) {
    my @pks;			# for future multiple key support
    push @pks, shift @$item foreach $class->columns('Primary');
    my $id = $pks[0];
    $id =~ s/^0+//;		# In case zerofill is on .
    my $val = defined $id ? $id : '';
    my $opt = HTML::Element->new("option", value =>$val);
    $opt->attr(selected => "selected") if $selected->{$id};
    my $content = ($class and $stringify and $class->can($stringify)) ? 
      $class->$stringify($_) : 
	join( '/', map { $_ if $_; }@{$item} );
    $opt->push_content( $content );
    push @res, $opt; 
  }
  return @res;
}


sub _options_from_array {
  my ($self, $items, $args) = @_;
  my $selected = $args->{selected} || {};
  my @res;
  for (@$items) {
    my $val = defined $_ ? $_ : '';
    my $opt = HTML::Element->new("option", value => $val);
    #$opt->attr(selected => "selected") if $selected =~/^$id$/;
    $opt->attr(selected => "selected") if $selected->{$_};
    $opt->push_content( $_ );
    push @res, $opt;
  }
  return @res;
}

sub _options_from_hash {
  my ($self, $items, $args) = @_;
  my $selected = $args->{selected} || {};
  my @res;

  my @values = values %$items;
  # hash Key is the option content  and the hash value is option value
  for (sort keys %$items) {
    my $val = defined $items->{$_} ? $items->{$_} : '';
    my $opt = HTML::Element->new("option", value => $val);
    $opt->attr(selected => "selected") if $selected->{$items->{$_}};
    $opt->push_content( $_ );
    push @res, $opt;
  }
  return @res;
}


sub _options_from_hashes {
  my ($self, $items, $args) = @_;
  my $selected = $args->{selected} || {};
  my $pk = eval {$args->{class}->primary_column} || 'id';
  my $fclass = $args->{class} || '';
  my $stringify = $args->{stringify};
  $stringify ||= $self->stringify_column if ( $self->can('stringify_column') );
  my @res;
  for my $item (@$items) {
    my $val = defined $item->{$pk} ? $item->{$pk} : '';
    my $opt = HTML::Element->new("option", value => $val);
    $opt->attr(selected => "selected") if $selected->{$val};
    my $content;
    if ($fclass and $stringify and $fclass->can($stringify)) {
      $content = bless ($item,$fclass)->$stringify();
    } elsif ( $stringify ) {
      $content = $item->{$stringify};
    } else {
      $content = join(' ', map {$item->{$_} } keys %$item);
    }

    $opt->push_content( $content );
    push @res, $opt;
  }
  return @res;
}


=head2 _to_checkbox 

Makes a checkbox element -- TODO

=cut
# 
# checkboxes: if no data in hand (ie called as class method), replace
# with a radio button, in order to allow this field to be left
# unspecified in search / add forms.
# 
# Not tested
# TODO  --  make this general checkboxse
# 
#
sub _to_checkbox {
    my ($self, $col, $args) = @_;
    my $nullable = eval {self->column_nullable($col)} || 0; 
    return $self->_to_radio($col) if !ref($self) || $nullable;
    my $value = $self->$col;
    my $a = HTML::Element->new("input", type=> "checkbox", name => $col);
    $a->attr("checked" => 'true') if $value eq 'Y';
    return $a;
}

=head2 _to_radio

Makes a radio button element -- TODO

=cut
# TODO  -- make this general radio butons
#
sub _to_radio {
  my ($self, $col) = @_;
  my $value = ref $self && $self->$col || '';
  my $nullable = eval {self->column_nullable($col)} || 0; 
  my $a = HTML::Element->new("span");
  my $ry = HTML::Element->new("input", type=> "radio", name=>$col, value=>'Y' );
  my $rn = HTML::Element->new("input", type=> "radio", name=>$col, value=>'N' );
  my $ru = HTML::Element->new("input", type=> "radio", name=>$col, value=>'' ) if $nullable;
  $ry->push_content('Yes'); $rn->push_content('No');
  $ru->push_content('n/a') if $nullable;
  if ($value eq 'Y') {
    $ry->attr("checked" => 'true');
  } elsif ($value eq 'N') {
    $rn->attr("checked" => 'true');
  } elsif ($nullable) {
    $ru->attr("checked" => 'true');
  }
  $a->push_content($ry, $rn);
  $a->push_content($ru) if $nullable;
  return $a;
}


=head1 CHANGES

1.0 
15-07-2004 -- Initial version

=head1 MAINTAINER 

Maypole Developers

=head1 AUTHORS

Peter Speltz, Aaron Trevena 

=head1 AUTHORS EMERITUS

Simon Cozens, Tony Bowden

=head1 TODO

  Testing - lots
  checkbox generalization
  radio generalization
  Make link_hidden use standard make_url stuff when it gets in Maypole
  How do you tell AF --" I want a has_many select box for this every time so,
     when you call "to_field($this_hasmany)" you get a select box

=head1 BUGS and QUERIES

Please direct all correspondence regarding this module to:
 Maypole list.

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2004 by Simon Cozens / Tony Bowden
Copyright 2006 Peter Speltz
Copyright 2007, 2008 Aaron Trevena

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Class::DBI>, L<Class::DBI::FromCGI>, L<HTML::Element>.

=cut

1;
