#!/usr/bin/perl -w
use Test::More;
use lib 'examples'; # Where BeerDB should live
BEGIN {
    $ENV{BEERDB_DEBUG} = 2;

    eval { require BeerDB };
    Test::More->import( skip_all =>
        "SQLite not working or BeerDB module could not be loaded: $@"
    ) if $@;

    plan tests =>21;
    
}
use Maypole::CLI qw(BeerDB);
use Maypole::Constants;
$ENV{MAYPOLE_TEMPLATES} = "t/templates";

isa_ok( (bless {},"BeerDB") , "Maypole");



# Test create missing required 
like(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit?name=&url=www.sammysmiths.com&notes=Healthy Brew"), qr/name' => 'This field is required/, "Required fields necessary to create ");

# Test create with all  required
like(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit?name=Samuel Smiths&url=www.sammysmiths.com&notes=Healthy Brew"), qr/^# view/, "Created a brewery");
     
($brewery,@other) = BeerDB::Brewery->search(name=>'Samuel Smiths'); 


SKIP: {
    skip "Could not create and retrieve Brewery", 8 unless $brewery;
	like(eval {$brewery->name}, qr/Samuel Smiths/, "Retrieved Brewery, $brewery, we just created");

	#-------- Test updating printable fields ------------------   

    # TEST clearing out  required printable column 
	like(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit/".$brewery->id."?name="), qr/name' => 'This field is required/, "Required printable field can not be cleared on update");

	# Test cgi update errors hanging around from last request 
	unlike(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit/".$brewery->id), qr/name' => 'This field is required/, "cgi_update_errors did not persist"); 

	# Test update no columns 
	like(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit/".$brewery->id), qr/^# view/, "Updated no columns"); 
	
	# Test only updating one non required column
	like(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit/".$brewery->id."?notes="), qr/^# view/, "Updated a single non required column"); 

	# TEST empty input for non required  printable 
	like(BeerDB->call_url("http://localhost/beerdb/brewery/do_edit/".$brewery->id."?notes=&name=Sammy Smiths"), qr/^# view/, "Updated brewery" );

	# TEST update actually cleared out a printable field
	$val  = $brewery->notes ;
    if ($val eq '') { $val = undef }; 
	is($val, undef, "Verified non required printable field was cleared");

	# TEST update did not change a field not in parameter list
	is($brewery->url, 'www.sammysmiths.com', "A field not in parameter list is not updated.");
};

#-----------------  Test other types of  fields --------------

$style = BeerDB::Style->insert({name => 'Stout', notes => 'Rich, dark, creamy, mmmmmm.'});

# TEST create with integer, date, printable fields
like(BeerDB->call_url("http://localhost/beerdb/beer/do_edit?name=Oatmeal Stout&brewery=".$brewery->id."&style=".$style->id."&score=5&notes=Healthy Brew&price=5.00&tasted=2000-12-01"),  qr/^# view/, "Created a beer with date, integer and printable fields");

($beer, @other) = BeerDB::Beer->search(name=>'Oatmeal Stout');

SKIP: {
	skip "Could not create and retrieve Beer", 7 unless $beer;

	# TEST wiping out an integer field
	like(BeerDB->call_url("http://localhost/beerdb/beer/do_edit/".$beer->id."?name=Oatmeal Stout&brewery=".$brewery->id."&style=".$style->id."&score=&notes=Healthy Brew&price=5.00"),  qr/^# view/, "Updated a beer");

	# TEST update actually cleared out a the integer field
	$val  = $beer->score ;
    if ($val eq '') { $val = undef }; 
	is($val, undef, "Verified non required integer field was cleared");

	
	# TEST invalid integer field
	like(BeerDB->call_url("http://localhost/beerdb/beer/do_edit/".$beer->id."?name=Oatmeal Stout&brewery=".$brewery->id."&style=Stout&price=5.00"),  qr/style' => 'Please provide a valid value/, "Integer field invalid");

	# TEST update with empty  date field
	like(BeerDB->call_url("http://localhost/beerdb/beer/do_edit/".$beer->id."?name=Oatmeal Stout&brewery=".$brewery->id."&style=".$style->id."&tasted=&notes=Healthy Brew&price=5.00"),  qr/^# view/, "Updated a beer");

	# TEST update actually cleared out a  date field
	$tasted = $beer->tasted ;
    if ($tasted eq '') { $tasted = undef }; 
	is($tasted, undef, "Verified non required date field was cleared.");

	# TEST invalid date 
	like(BeerDB->call_url("http://localhost/beerdb/beer/do_edit/".$beer->id."?name=Oatmeal Stout&brewery=".$brewery->id."&style=".$style->id."&tasted=baddate&notes=Healthy Brew&price=5.00"),  qr/tasted' => 'Please provide a valid value/, "Date field invalid");

	# TEST  negative value allowed for required field
	like(BeerDB->call_url("http://localhost/beerdb/beer/do_edit/".$beer->id."?name=Oatmeal Stout&brewery=".$brewery->id."&price=-5.00"),  qr/^# view/, "Negative values allowed for required field");
	
	# TEST negative value actually got stored
	like($beer->price, qr/-5(\.00)?/, "Negative value for required field stored in database") 
};
 
$beer_id = $beer->id;
$beer->delete;

# TEST delete
$beer = BeerDB::Beer->retrieve($beer_id);
is($beer, undef, "Deleted Beer");

$brewery->delete;
$style->delete;
