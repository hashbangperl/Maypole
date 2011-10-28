package Maypole::Model::DBIC;
use strict;
use Carp qw(confess);

=head1 NAME

Maypole::Model::DBIC - Model class based on DBIx::Class

=head1 SYNOPSIS

    package Foo;
    use 'Maypole::Application';

    Foo->config->model("Maypole::Model::DBIC");
    Foo->setup([qw/ Foo::SomeTable Foo::Other::Table /], $schema);


=head1 DESCRIPTION

This module allows you to use Maypole with previously set-up
L<DBIx::Class> classes; simply call C<setup> with a list reference
of the classes you're going to use, and Maypole will work out the
tables and set up the inheritance relationships as normal.

=cut

use Data::FormValidator;

use Lingua::EN::Inflect::Number qw(to_PL);


use Data::Dumper;
$Data::Dumper::MaxDepth = 2;

use Maypole::Config;

use base qw(Maypole::Model::Base Class::Data::Inheritable);
use attributes ();

Maypole::Config->mk_accessors(qw(table_to_class classes class_to_moniker class_to_table dbic_schema _COLUMN_INFO));
Maypole::Model::DBIC->mk_classdata('_columns');
Maypole::Model::DBIC->mk_classdata('table');
Maypole::Model::DBIC->mk_classdata('_relation_names');
Maypole::Model::DBIC->mk_classdata('_relation_info');

=head1 METHODS

=head2 setup

  This method is inherited from Maypole::Model::Base and calls setup_database,
  which uses Class::DBI::Loader to create and load Class::DBI classes from
  the given database schema.

=head2 setup_database

  This method loads and sets up the model classes for the application

  Maypole::Model::DBIC->setup_database($config, $classes, $schema_obj);

  # Foo::Model::Bar should map to Foo::Data::Bar and 'bar' table
  __PACKAGE__->setup([qw/ Bar => 'Foo::Model::Bar' /], $schema);

=cut

sub setup_database {
    my ( $class, $config, $driver_class, $classes, $schema ) = @_;
    warn "setup_database called with : $class, $config, $driver_class, $classes, $schema\n";

    $config->{table_to_class} = { map { $schema->resultset($_)->result_source->name => $classes->{$_} } keys %$classes };

    $config->{class_to_moniker} = { map { $classes->{$_} => $_ } keys %$classes };

    $config->{class_to_table} = { map { $config->{table_to_class}->{$_} => $_ } keys %{ $config->{table_to_class} } };

    $config->{classes} = [ values %$classes ];

    $config->{tables}         = [ keys %{ $config->{table_to_class} } ];

    $config->{dbic_schema} = $schema;

    # __PACKAGE__->setup([qw/ Bar => 'Foo::Model::Bar' /], $schema);
    # Foo::Model::Bar should map to Foo::Data::Bar and 'bar' table

#    warn Dumper ($config);

    warn "setting up classes\n";
    foreach my $class (@{$config->{classes}}) {
      $driver_class->load_model_subclass($class);
      $class->table($config->{class_to_table}->{$class});
      my $rs = $schema->resultset($config->class_to_moniker->{$class})->result_source;
      $class->_columns([$rs->columns]);

      my $rel_names = [ $rs->relationships ];
      $class->_relation_names($rel_names);
      my $rel_info = $rs->relationship_info || {};
      $class->_relation_info($rel_info);
    }

    $driver_class->model_classes_loaded(1);
    return;
}

=head2 class_of

  returns class for given table

=cut

sub class_of {
    my ( $self, $r, $table ) = @_;
    warn "class_of called\n";
    return $r->config->{table_to_class}->{$table};
}

=head2 columns

=cut

sub columns {
  my $self  = shift;
  warn "columns called\n";
  my $cols = $self->_columns || [];
  return @$cols;
}

=head2 related

=cut

sub related {
  my $self = shift;
  return @ {$self->_relation_names };
}


=head2 find_column

=cut

sub find_column {
  my ($self, $col) = @_;
  return grep ($_ eq $col, $self->columns);
}


=head2 add_model_superclass

Adds model as superclass to model classes (if necessary)

=cut

sub add_model_superclass { return ;}

sub fetch_objects { return ; }

=head1 Action Methods

Action methods are methods that are accessed through web (or other public) interface.

=head2 list

=cut

sub list : Exported {
    my ( $class, $r ) = @_;

#    $r->build_form_elements(0);
    warn "list called with args : ", join (', ', @_), "\n";

    my $config   = $r->config;
    my $table    = $r->table;

    warn "config : $config, table : $table\n";

    my $data_class_moniker = $config->class_to_moniker->{$class};
    my $schema = $config->dbic_schema;
    warn "data_class_moniker : $data_class_moniker, schema: $schema\n";

    my $rs = $schema->resultset($data_class_moniker);
    warn "rs : $rs\n";

    my $order = $class->order($r, $rs);
#    $self = $self->do_pager($r);
    my $search_attr = { };
    $search_attr->{order} = $order if ($order);
    my $objects = [ $rs->search({},$search_attr) ];
    $r->objects( $objects );

    warn Dumper (objects => $objects);

    return;
}


=head2 order

    Returns the SQL order syntax based on the order parameter passed
    to the request, and the valid columns.. i.e. 'title ASC' or 'date_created DESC'.

    $sql .= $self->order($r);

    If the order column is not a column of this table,
    or an order argument is not passed, then the return value is undefined.

    Note: the returned value does not start with a space.

=cut

sub order {
    my ( $self, $r, $rs ) = @_;
    my %ok_columns = map { $_ => 1 } $rs->result_source->columns;
    my $q = $r->query;
    my $order = $q->{order};
    return unless $order and $ok_columns{$order};
    $order .= ' DESC' if $q->{o2} and $q->{o2} eq 'desc';
    return $order;
}


=head1 SEE ALSO

L<Maypole>, L<Maypole::Model::Base>.

=head1 AUTHOR

Maypole is currently maintained by Aaron Trevena.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;

