package HTML::DBForm::Search;

use strict;
use base qw(Class::Factory);

our $VERSION = '1.00';

sub run	{ die "define run() in implementation" };

__PACKAGE__->add_factory_type( dropdown	=> 'HTML::DBForm::Search::DropDown');

1;
