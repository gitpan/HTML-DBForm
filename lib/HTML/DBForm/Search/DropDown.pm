package HTML::DBForm::Search::DropDown;

use 5.008;
use strict;
use warnings;

use HTML::Template;

our $VERSION = '1.00';

=head1 NAME

HTML::DBForm::Search::DropDown - Creates a web interface for searching database tables

=head1 SYNOPSIS

    $search = HTML::DBForm::Search->new('dropdown',
    [{
        column => 'id',
        sql    => 'select id, name from contacts',
    }]);
	
    $editor->run(search => $search);


=head1 INTRODUCTION

  HTML::DBForm::Search::DropDown provides a web interface to search for rows
  in a database to be updated by HTML::DBForm. 

=cut

=head1 METHODS

=over 4

=cut



# implementation of this method is required
# constructor inherited from Class::Factory 
# via HTML::DBForm::Search

sub init {

	my $self = shift;
	$self->{params} = \@_;
	
	return $self;
}




# implementation of this method is required
# main subroutine called by HTML::DBForm

sub run {

	my ($self, $editor) = @_;

	my $tmpl_ref = $self->{tmpl_file} 
		? do { open(FH, "< $self->{tmpl_file}"); 
				local $/; 
				<FH> } 
		: &TEMPLATE ;


	$self->{template} = HTML::Template->new(
		scalarref => \$tmpl_ref, 
		die_on_bad_params => 0,
		loop_context_vars => 1,
	);

	$self->{editor} = $editor;
	
	# find out what step we are on
	$self->{step} = $self->{editor}->{query}->param('step') || 0;
	
	$self->{template}->param(STEP => $self->{step} + 1);
	
	$self->get_choices;

	return ($self->{editor}->{error}) ? 
		$self->{editor}->{template}->output :
		$self->{template}->output ;
	
}


=item set_template

Sets an optional HTML::Template file

Takes a scalar holding the path to a template file.
You can get a template to start with by doing:

 perl -MHTML::DBForm::Search::DropDown -e 
 'print HTML::DBForm::Search::DropDown::TEMPLATE()' > sample.tmpl


B<Example>

  $search->set_template('/path/to/template.tmpl');


=cut

sub set_template {

	my $self = shift;
	my $tmpl = shift;

	$self->{tmpl_file} = $tmpl;
}



# get choices to display 

sub get_choices {

	my $self = shift;

	if ($self->{params}->[$self->{step}]->{sql}){

		# use sql parameter
		$self->populate_search(
			$self->{params}->[$self->{step}]->{sql}->[1]
		);

	} else {

		# generate our own sql
		$self->populate_search(
			$self->get_select($self->parse_params($self->{step}))
		);
	}
}



# parse search parameters 
 
sub parse_params {

	my $self = shift;
	my $i = shift;

	my $c_param = $self->{params}->[$i];

	if ($c_param->{column}){
		return	($c_param->{column}, $c_param->{column});
	} 

	if ($c_param->{columns})  {
		return	($c_param->{columns}->[0], $c_param->{columns}->[1]);
	} 

	if ($c_param->{sql}) {
		return	($c_param->{sql}->[0], $c_param->{sql}->[1]);
	} 
}



# build a select statement
 
sub get_select {

	my $self = shift;
	my ($col1, $col2) = @_;

	my $sql = qq(	SELECT	DISTINCT $col1, $col2 
 					FROM	$self->{editor}->{table}  
					);	

	return $sql.' ORDER BY '.$col2 unless $self->{step};

	my (@values, $i);
	
	for my $step(0 .. $self->{step}-1){

		$sql .= ' WHERE ' unless $i++;
		$sql .= ($self->parse_params($step))[0] ." = ?"; 
		$sql .= ' AND ' unless $step >= $self->{step}-1;		

		push @values, 
			$self->{editor}->{query}->param(($self->parse_params($step))[0]);
	}

	$sql .= ' ORDER BY '. $col2;


	# the sql is the first element
	# the rest of the array is 
	# filled with placeholder vals

	unshift @values, $sql;
	return @values;

}



# populate search choices 

sub populate_search {

	my $self = shift;
	my ($sql, @params) = @_;
	my (@tmpl_loop, $db_return);
	
	eval{
		$db_return = $self->{editor}->{dbh}->selectall_arrayref($sql, undef, @params);
	1 } or $self->{editor}->_err_msg($@, $sql);

	# workaround for servers that lack
	# subqueries ( e.g mysql < 4.1 )

	if ($self->{params}->[$self->{step}]->{sql}){
		$db_return = $self->constrain_results($db_return);
	};


	for my $row_ref(@$db_return){
		my %row = (
			VALUE => $row_ref->[0],		
			LABEL => $row_ref->[1],
		);		
		push(@tmpl_loop, \%row);
	}


	# keep track of old choices
	my @prev_vals; 
	for my $step(0 .. $self->{step}-1){
		my %row;
		$row{LABEL} = ($self->parse_params($step))[0];
		$row{VALUE} = $self->{editor}->{query}->param(($self->parse_params($step))[0]);	
		push @prev_vals, \%row;
	}


	# is this the last step?
	my $rm = (($self->{step}+1) >= scalar(@{$self->{params}})) ? 'display' :'';


	# is it the first?
	my $cancel = ($self->{step} > 0) ? 1 : 0;


	$self->{template}->param(	SEARCH_LOOP	=> \@tmpl_loop, 
								FORM 		=> 1,
								SELECT_NAME	=> ($self->parse_params($self->{step}))[0],
								RUN_MODE	=> $rm,
								CANCEL		=> $cancel,
								PREV_VALS	=> \@prev_vals,
							); 	
}



# discard extra sql returns 

sub constrain_results {
	
	# this would be much cleaner 
	# but less portable using subqueries 
	# instead of two seperate queries

	my ($self, $list) = @_;

	# get a list of all possible
	# results based on previous selections	
	my $editor = $self->{editor};

	my $sql = qq(	SELECT	DISTINCT 
			$self->{params}->[$self->{step}]->{sql}->[0] 
 			FROM	$editor->{table}  
					);	

	my (@values, $i, @results);
	
	for my $step(0 .. $self->{step}-2){

		$sql .= ' WHERE ' unless $i++;
		$sql .= ($self->parse_params($step))[0] ." = ?"; 
		$sql .= ' AND ' unless $step >= $self->{step}-2;		

		push @values, 
			$editor->{query}->param(($self->parse_params($step))[0]);
	}

	my $selections;
	
	eval{
		$selections = 
		$editor->{dbh}->selectcol_arrayref($sql, undef, @values); 1
		} or $editor->_err_msg($@, $sql);

	for my $lr(@$list){
		push (@results, $lr) if grep{/^$lr->[0]$/} @$selections;
	}
	
	return \@results;
}




sub TEMPLATE {

qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" >
<html>
<head>
<style>

		.medium_text{	
			font-family:arial, helvetica, sans-serif; 
			font-weight:normal; 
			font-size:11px;  
			color:#333333;
		}
		
		.large_text {
			font-family:arial, helvetica, sans-serif; 
			font-weight:bold; 
			font-size:11px;  
			color:#333333;
		}


		INPUT, TEXTAREA, SELECT, OPTION, SUBMIT {
          font-family: Arial, Helvetica, Sans-Serif;
		  font-size: 11px;
          padding:2px;
          color: #333;
          /*background-color: #fff;*/
          border: solid 1px #666;
          } 
		  
	</style>
</head>

<body style="margin: 0 0 0 0;" marginwidth="0" marginheight="0" width="100%" bgcolor="#ffffff">

<table cellpadding="0" cellspacing="20" border="0">
  <tr>
    <td>
 
	<!--             -->
	<!-- SEARCH AREA -->
	<!--             -->
    
	<!-- TMPL_IF FORM -->

		<form name="form1" enctype="multipart/form-data" method="post">

		<table cellpadding='10'>
		<tr>
			<td class="large_text">	

			Edit or Create a Record: <p>

			<select name='<!-- TMPL_VAR SELECT_NAME -->' >
			
			<!-- TMPL_LOOP SEARCH_LOOP -->

			<option value='<!--TMPL_VAR VALUE -->'> <!-- TMPL_VAR LABEL --> </option>

			<!-- /TMPL_LOOP -->

			</select>

			</td>
		</tr>
		<tr>
			<td>

				<!-- HIDDEN HTML FORM ELEMENTS -->

				<input type="hidden" name="step" value="<!-- TMPL_VAR STEP -->">	
				<input type="hidden" name="rm" value="<!-- TMPL_VAR RUN_MODE -->">	
	
				<!-- TMPL_LOOP PREV_VALS -->
				<input type="hidden" name="<!-- TMPL_VAR LABEL -->" value="<!-- TMPL_VAR VALUE -->">
				<!-- /TMPL_LOOP -->

				<!-- END HIDDEN HTML ELEMENTS -->


				<input type="submit" value="Submit" style="width:80;">
		
				<!-- TMPL_IF CANCEL -->
		
				<input type='button' value='Cancel ' onclick='document.location="javascript:history.go(-1)"'
				style="width:80;">
			
				<!-- /TMPL_IF -->	
	
				<input type='button' value='Add New' onclick='document.location="<!-- TMPL_VAR URL -->?rm=display"'
				style="width:80;">


			</td>
		</tr>
		</table>

	</form>
	<!-- /TMPL_IF -->


   </td>
  </tr>
</table>
</body>
</html>);
}


1;
