package Maypole::Model::AsForm;
use strict;

=head1 NAME

Maypole::Model:AsForm - Produce HTML form elements for database columns

=head1 SYNOPSIS

    sub create_or_edit {
        my $self = shift;
        my %cgi_field = $self->to_cgi;
        return start_form,
               (map { "<b>$_</b>: ". $cgi_field{$_}->as_HTML." <br>" } 
                    $class->Columns),
               end_form;
    }


   . . .

   # Somewhere else in a Maypole application about beer...


   Beer->to_field('brewery', 'textfield', {
		name => 'brewery_id', value => $beer->brewery,
   });

   # Rate a beer
   Beer->to_field(rating => { select => {
		items => [1 , 2, 3, 4, 5],
   } });

   # Select a Brewery to visit in the UK
   Brewery->to_field(brewery_id => {
		items => [ Brewery->search_like(location => 'UK') ],
   });

   # Make a select for a boolean field
   Pub->to_field('open' , { items => [ {'Open' => 1, 'Closed' => 0 } ] }); 

   Beer->to_field('brewery', {
		selected => $beer->brewery, # again not necessary since caller is obj.
   });


   Beer->to_field('brewery', 'link_hidden', {r => $r, uri => 'www.maypole.perl.org/brewery/view/'.$beer->brewery});
    # an html link that is also a hidden input to the object. R is required to
    # make the uri  unless you  pass a  uri



    #####################################################
    # Templates Usage

    <form ..>

    ...

    <label>

     <span class="field"> [% classmetadata.colnames.$col %] : </span>

     [% object.to_field(col).as_XML %]

    </label>

    . . .

    <label>

     <span class="field"> Brewery : </span>

     [% object.to_field('brewery', { selected => 23} ).as_XML %]

    </label>

    . . .

    </form>


    #####################################################
    # Advanced Usage

    # has_many select
    package Job;
    __PACKAGE__->has_a('job_employer' => 'Employer');
    __PACKAGE__->has_a('contact'  => 'Contact')

    package Contact;
    __PACKAGE__->has_a('cont_employer' => 'Employer');
    __PACKAGE__->has_many('jobs'  => 'Job',
			  { join => { job_employer => 'cont_employer' },
			    constraint => { 'finshed' => 0  },
			    order_by   => "created ASC",
			  }
			 );

    package Employer;
    __PACKAGE__->has_many('jobs'  => 'Job',);
    __PACKAGE__->has_many('contacts'  => 'Contact',
			  order_by => 'name DESC',
			 );


  # Choose some jobs to add to a contact (has multiple attribute).
  my $job_sel = Contact->to_field('jobs'); # Uses constraint and order by


  # Choose a job from $contact->jobs 
  my $job_sel = $contact->to_field('jobs');


=head1 DESCRIPTION

This module helps to generate HTML forms for creating new database rows
or editing existing rows. It maps column names in a database table to
HTML form elements which fit the schema. Large text fields are turned
into textareas, and fields with a has-a relationship to other
tables are turned into select drop-downs populated with
objects from the joined class.


=head1 ARGUMENTS HASH

This provides a convenient way to tweak AsForm's behavior in exceptional or 
not so exceptional instances. Below describes the arguments hash and 
example usages. 


  $beer->to_field($col, $how, $args); 
  $beer->to_field($col, $args);

Not all _to_* methods pay attention to all arguments. For example, '_to_textfield' does not look in $args->{'items'} at all.

=over

=item name -- the name the element will have , this trumps the derived name.

  $beer->to_field('brewery', 'readonly', {
		name => 'brewery_id'
  });

=item value -- the initial value the element will have, trumps derived value

  $beer->to_field('brewery', 'textfield', { 
		name => 'brewery_id', value => $beer->brewery,
		# however, no need to set value since $beer is object
  });

=item items -- array of items generally used to make select box options

Can be array of objects, hashes, arrays, or strings, or just a hash.

   # Rate a beer
   $beer->to_field(rating =>  select => {
		items => [1 , 2, 3, 4, 5],
   });

   # Select a Brewery to visit in the UK
   Brewery->to_field(brewery_id => {
		items => [ Brewery->search_like(location => 'UK') ],
   });

  # Make a select for a boolean field
  $Pub->to_field('open' , { items => [ {'Open' => 1, 'Closed' => 0 } ] }); 

=item selected -- something representing which item is selected in a select box

   $beer->to_field('brewery', {
		selected => $beer->brewery, # again not necessary since caller is obj.
   });

Can be an simple scalar id, an object, or an array of either

=item class -- the class for which the input being made for field pertains to.

This in almost always derived in cases where it may be difficult to derive, --
   # Select beers to serve on handpump
   Pub->to_field(handpumps => select => {
		class => 'Beer', order_by => 'name ASC', multiple => 1,
	});

=item column_type -- a string representing column type

  $pub->to_field('open', 'bool_select', {
		column_type => "bool('Closed', 'Open'),
  });

=item column_nullable -- flag saying if column is nullable or not

Generally this can be set to get or not get a null/empty option added to
a select box.  AsForm attempts to call "$class->column_nullable" to set this
and it defaults to true if there is no shuch method.

  $beer->to_field('brewery', { column_nullable => 1 });    

=item r or request  -- the Mapyole request object 

=item uri -- uri for a link , used in methods such as _to_link_hidden

 $beer->to_field('brewery', 'link_hidden', 
	  {r => $r, uri => 'www.maypole.perl.org/brewery/view/'.$beer->brewery}); 
 # an html link that is also a hidden input to the object. R is required to
 # make the uri  unless you  pass a  uri

=item order_by, constraint, join

These are used in making select boxes. order_by is a simple order by clause
and constraint and join are hashes used to limit the rows selected. The
difference is that join uses methods of the object and constraint uses 
static values. You can also specify these in the relationship definitions.
See the relationships documentation of how to set arbitrayr meta info. 

  BeerDB::LondonBeer->has_a('brewery', 'BeerDB::Brewery', 
		   order_by     => 'brewery_name ASC',
	   constraint   => {location  => 'London'},
	   'join'       => {'brewery_tablecolumn  => 'beer_obj_column'}, 
	  );

=item no_hidden_constraints -- 

Tell AsForm not to make hidden inputs for relationship constraints. It does
this  sometimes when making foreign inputs. However, i think it should not
do this and that the FromCGI 's _create_related method should do it. 

=head2 METHODS

=head2 to_cgi

  Beer->to_cgi([@columns, $args]); 

This returns a hash mapping all the column names to HTML::Element objects 
representing form widgets.  It takes two opitonal arguments -- a list of 
columns and a hashref of hashes of arguments for each column.  If called with an object like for editing, the inputs will have the object's values.

  Beer->to_cgi({object => $beer}); # uses $self->columns;  # most used
  Beer->to_cgi(qw/brewery style rating/, {object => $beer }); # sometimes
  # and on rare occassions this is desireable if you have a lot of fields
  # and dont want to call to_field a bunch of times just to tweak one or 
  # two of them.
  Beer->to_cgi(@cols, { brewery => {
                                      how => 'textfield' # too big for select 
                                   },
                        style   => {
                                       column_nullable => 0, 
                                       how => 'select', 
                                       items => ['Ale', 'Lager']
                                   },
                        object => $beer,
  });

=cut

sub to_cgi {
  my ($class, @columns) = @_;
  my $args = {};
  if ( ref $columns[-1] eq 'HASH' ) {
    $args = pop @columns;
  }

  if (not @columns) {
    @columns = $class->columns;
  }

  map { $_ => $class->to_field($_, $args->{$_}, $args->{object}) } @columns;
}

=head2 to_field($field [, $how][, $args], [$object])

This maps an individual column to a form element. The C<how> argument
can be used to force the field type into any you want. All that you need 
is a method named "_to_$how" in your class. Your class inherits many from
AsForm  already. 

If C<how> is specified but the class cannot call the method it maps to,
then AsForm will issue a warning and the default input will be made. 
You can write your own "_to_$how" methods and AsForm comes with many.
See C<HOW Methods>. You can also pass this argument in $args->{how}.


=cut

sub to_field {
  my ($class, $field, $how, $args, $obj) = @_;
  if (ref $how)   { $args = $how; $how = ''; }
  unless ($how)   { $how = $args->{how} || ''; }
  $args ||= {};

  unless ($obj) {
    $obj = $_[-1] if ($_[-1] && ref($_[-1]) && UNIVERSAL::can($_[-1],'isa'));
    $args->{object} = $obj if ($obj);
  }

  #warn "In to_field field is $field how is $how. args are" . Dumper($args) . " \n";
  # Set sensible default value
  if  ($field and not defined $args->{default}) { 
      if ($class->can('column_default')) {
	  my $def = $class->column_default($field) ;
	  # exclude defaults we don't want actually put as value for input
	  if (defined $def) {
	      $def = $def =~ /(^0000-00-00.*$|^0[0]*$|^0\.00$|CURRENT_TIMESTAMP|NULL)/i ? '' : $def ;
	      $args->{default} = $def;
	  }
      }
  }

  return	$class->_field_from_how($field, $how, $args, $obj)   ||
    $class->_field_from_relationship($field, $args, $obj) ||
      $class->_field_from_column($field, $args, $obj)  ||
	$class->_to_textfield($field, $args, $obj);
}


=head2 unselect_element

  unselect any selected elements in a HTML::Element select list widget

=cut

sub unselect_element {
  my ($self, $el) = @_;
  if (ref $el && $el->can('tag') && $el->tag eq 'select') {
    foreach my $opt ($el->content_list) {
      $opt->attr('selected', undef) if $opt->attr('selected');
    }
  }
}

=head2 _field_from_how($field, $how,$args, $obj)

Returns an input element based the "how" parameter or nothing at all.
Override at will.

=cut

sub _field_from_how {
  my ($class, $field, $how, $args, $obj) = @_;
  return unless $how;
  $args ||= {};
  unless ($obj) {
    $obj = $_[-1] if ($_[-1] && ref($_[-1]) && UNIVERSAL::can($_[-1],'isa'));
  }

  no strict 'refs';
  my $meth = "_to_$how";
  if (not $class->can($meth)) {
    warn "Class can not $meth";
    return;
  }
  return $class->$meth($field, $args, $obj);
}

# Makes a readonly input box out of column's value
# No args makes object to readonly
sub _to_readonly {
  my ($class, $col, $args, $obj) = @_;
  my $val = $args->{value};
  if (not defined $val ) {	# object to readonly
    $class->_croak("AsForm: To readonly field called as class method without a value") unless ref $class;
    $val = $class->id;
    $col = $class->primary_column;
  }
  my $a = HTML::Element->new('input', 'type' => 'text', readonly => '1',
			     'name' => $col, 'value'=>$val);
  return $a;
}




=head2 _to_enum_select

Returns a select box for the an enum column type. 

=cut

sub _to_enum_select {
  my ($class, $col, $args, $obj) = @_;
  my $type = $args->{column_type};
  unless ($obj) {
    $obj = $_[-1] if ($_[-1] && ref($_[-1]) && UNIVERSAL::can($_[-1],'isa'));
  }
  $type =~ /ENUM\((.*?)\)/i;
  (my $enum = $1) =~ s/'//g;
  my @enum_vals = split /\s*,\s*/, $enum;

  # determine which is pre selected
  my $selected = eval { $obj->$col  };
  $selected = $args->{default} unless defined $selected;
  $selected = $enum_vals[0] unless defined $selected;

  my $a = HTML::Element->new("select", name => $col);
  for ( @enum_vals ) {
    my $sel = HTML::Element->new("option", value => $_);
    $sel->attr("selected" => "selected") if $_ eq $selected ;
    $sel->push_content($_);
    $a->push_content($sel);
  }

  return $a;
}


=head2 _to_bool_select

Returns a "No/Yes"  select box for a boolean column type. 

=cut

# TODO fix this mess with args
sub _to_bool_select {
  my ($class, $col, $args, $obj) = @_;
  my $type = $args->{column_type};
  unless ($obj) {
    $obj = $_[-1] if ($_[-1] && ref($_[-1]) && UNIVERSAL::can($_[-1],'isa'));
  }

  my @bool_text = ('No', 'Yes');
  if ($type =~ /BOOL\((.+?)\)/i) {
    (my $bool = $1) =~ s/'//g;
    @bool_text = split /,/, $bool;
  }

  # get selected 
  my $selected = $args->{value} if defined $args->{value};
  $selected = $args->{selected} unless defined $selected;
  $selected =  ref $obj ? eval {$obj->$col;} : $args->{default}
    unless (defined $selected);

  my $a = HTML::Element->new("select", name => $col);
  if ($args->{column_nullable} || !defined $args->{value} ) {
    my $null =  HTML::Element->new("option");
    $null->attr('selected', 'selected') if  (!defined $args->{value});
    $a->push_content( $null ); 
  }

  my ($opt0, $opt1) = ( HTML::Element->new("option", value => 0),
			HTML::Element->new("option", value => 1) ); 
  $opt0->push_content($bool_text[0]); 
  $opt1->push_content($bool_text[1]); 
  unless ($selected eq '') { 
    $opt0->attr("selected" => "selected") if not $selected; 
    $opt1->attr("selected" => "selected") if $selected; 
  }
  $a->push_content($opt0, $opt1);

  return $a;
}

=head2 _to_hidden($field, $args, $obj)

This makes a hidden html element input. It uses the "name" and "value" 
arguments. If one or both are not there, it will look for an object in 
"items->[0]" or the caller. Then it will use $field or the primary key for
name  and the value of the column by the derived name.

=cut

sub _to_hidden {
  my ($class, $field, $args, $object) = @_;
  unless ($object) {
    $object = $_[-1] if ($_[-1] && ref($_[-1]) && UNIVERSAL::can($_[-1],'isa'));
  }
  $args ||= {};
  my ($name, $value) = ($args->{'name'}, $args->{value});
  $name = $field unless defined $name;
  if (! defined $name and !defined $value) { # check for objects
    my $obj = $args->{items}->[0] || $object;
    unless (ref $obj) {
      die "_to_hidden cannot determine a value. It was passed a value argument or items object or called with an object.";
    }
    $name = $class->primary_column unless $name;
    $value = $obj->$name unless $value;
  }

  return HTML::Element->new('input', 'type' => 'hidden',
			    'name' => $name, 'value'=>$value);
}

=head2 _to_link_hidden($col, $args, $object)

Makes a link with a hidden input with the id of $obj as the value and name.
Name defaults to the objects primary key. The object defaults to self.

=cut

sub _to_link_hidden {
  my ($class, $accessor, $args, $object) = @_;
  my $r =  eval {$self->controller} || $args->{r} || '';
  my $uri = $args->{uri} || '';
  $self->_croak("_to_link_hidden cant get uri. No  Maypole Request class (\$r) or uri arg. Need one or other.")
    unless $r;
  my ($obj, $name);
  if (ref $object) {		# hidding linking self
    $obj  = $object;
    $name = $args->{name} || $obj->primary_column->name;
  } elsif ($obj = $args->{items}->[0]) {
    $name = $args->{name} || $accessor || $obj->primary_column->name; 
    # TODO use meta data above maybe
  } else {	       # hiding linking related object with id in args
    $obj  = $class->related_class($r, $accessor)->retrieve($args->{id});
    $name = $args->{name} || $accessor ; #$obj->primary_column->name;
    # TODO use meta data above maybe
  }
  $class->_croak("_to_link_hidden has no object") unless ref $obj;
  my $href =  $uri || $r->config->{uri_base} . "/". $obj->table."/view/".$obj->id;
  my $a = HTML::Element->new('a', 'href' => $href);
  $a->push_content("$obj");
  $a->push_content($self->to_field('blahfooey', 'hidden', {name => $name, value =>  $obj->id} ));

  return $a;
}



############################ HELPER METHODS ######################
##################################################################

=head2 _rename_foreign_input

_rename_foreign_input($html_el_or_hash_of_them); # changes made by reference

Recursively renames the foreign inputs made by _to_foreign_inputs so they 
can be processed generically.  It uses foreign_input_delimiter. 

So if an Employee is a Person who has_many  Addresses and you call and the
method 'foreign_input_delimiter' returns '__AF__' then 

  Employee->to_field("person");  
  
will get inputs for the Person as well as their Address (by default,
override _field_from_relationship to change logic) named like this: 

  person__AF__address__AF__street
  person__AF__address__AF__city
  person__AF__address__AF__state  
  person__AF__address__AF__zip  

And the processor would know to create this address, put the address id in
person->{address} data slot, insert the person and put the person id in the employee->{person} data slot and then insert the employee with that data.

=cut

sub _rename_foreign_input {
  my ($self, $accssr, $element) = @_;
  my $del = $self->foreign_input_delimiter;

  if ( ref $element ne 'HASH' ) {
    #	my $new_name = $accssr . "__AF__" . $input->attr('name');
    $element->attr( name => $accssr . $del . $element->attr('name'));
  } else {
    $self->_rename_foreign_input($accssr, $element->{$_}) 
      foreach (keys %$element);
  }
}

=head2 foreign_input_delimiter

This tells AsForm what to use to delmit forieign input names. This is important
to avoid name clashes as well as automating processing of forms. 

=cut

sub foreign_input_delimiter { '__AF__' };

=head2 _box($value) 

This functions computes the dimensions of a textarea based on the value 
or the defaults.

=cut

sub _box {
  my ($class, $min_rows, $max_rows, $min_cols, $max_cols) = (2 => 50, 20 => 100);
  my $text = shift;
  if ($text) {
    my @rows = split /^/, $text;
    my $cols = $min_cols;
    my $chars = 0;
    for (@rows) {
      my $len = length $_;
      $chars += $len;
      $cols = $len if $len > $cols;
      $cols = $max_cols if $cols > $max_cols;
    }
    my $rows = @rows;
    $rows = int($chars/$cols) + 1 if $chars/$cols > $rows;
    $rows = $min_rows if $rows < $min_rows;
    $rows = $max_rows if $rows > $max_rows;
    ($rows, $cols)
  } else {
    ($min_rows, $min_cols);
  }
}


=head1 MAINTAINER 

Maypole Developers

=head1 AUTHORS

Aaron Trevena 

=head1 BUGS and QUERIES

Please direct all correspondence regarding this module to:
 Maypole list.

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2004 by Simon Cozens / Tony Bowden
Copyright 2006 Peter Speltz
Copyright 2008 Aaron Trevena

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Class::DBI>, L<Class::DBI::FromCGI>, L<HTML::Element>.

=cut

1;
