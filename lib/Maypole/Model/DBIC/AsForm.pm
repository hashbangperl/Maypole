package Maypole::Model::DBIC::AsForm;
use strict;

=head1 NAME

Maypole::Model:DBIC::AsForm - Produce HTML form elements for database columns

=head1 SYNOPSIS

use Maypole::Model::DBIC::AsForm;

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




=head1 MAINTAINER 

Maypole Developers

=head1 AUTHORS

Aaron Trevena

=head1 BUGS and QUERIES

Please direct all correspondence regarding this module to:
 Maypole list.

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Aaron Trevena

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Maypole::Model::AsForm>, L<Class::DBI::FromCGI>, L<HTML::Element>.

=cut


1;
