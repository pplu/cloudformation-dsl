#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Data::Printer;

package TestClass {
  use CloudFormation::DSL;
  use CCfnX::CommonArgs;
  use CCfnX::InstanceArgs;

  has params => (is => 'ro', isa => 'CCfnX::CommonArgs', default => sub { CCfnX::InstanceArgs->new(
    instance_type => 'x1.xlarge',
    region => 'eu-west-1',
    account => 'devel-capside',
    name => 'NAME'
  ); } );

  output 'output1', Ref('XXX');
  output 'output2', GetAtt('XXX', 'InstanceID');
  output 'keyed/output', Ref('XXX');
  output 'export1', Ref('XXX'), {Export => { Name => 'myexportname' }};

  output outputwithcond1 => Ref('XXX'), { Condition => "thecond1" } ;
  output outputwithcond2 => GetAtt('XXX', 'InstanceID'), { Condition => "thecond2" };
  output outputwithcondandexport => GetAtt('XXX', 'InstanceID'), { Condition => "thecond", Export => { Name => 'myexportname' } };
}

package TestClassAddOutput {
  use CloudFormation::DSL;
  use CCfnX::CommonArgs;

  has params => (is => 'ro', default => sub { CCfnX::CommonArgs->new(account => 'X', name => 'N', region => 'X') });

}

my $obj = TestClass->new;
my $struct = $obj->as_hashref;

is_deeply($struct->{Outputs}->{output1}->{Value},
          { Ref => 'XXX' },
          'Got the correct structure for the output');

is_deeply($struct->{Outputs}->{output2}->{Value},
          { 'Fn::GetAtt' => [ 'XXX', 'InstanceID' ] },
          'Got the correct structure for the output');

# The / (slash) from keyed/output is missiing because CCfn supports slashed names
is_deeply($struct->{Outputs}->{keyedoutput}->{Value},
          { Ref => 'XXX' },
          'Got the correct structure for the output');

is_deeply($struct->{Outputs}->{export1},
  { Value => { Ref => 'XXX' },
    Export => { Name => 'myexportname' },
  },
  'Got the correct structure for the output');

is_deeply($struct->{Outputs}->{export1},
  { Value => { Ref => 'XXX' },
    Export => { Name => 'myexportname' },
  },
  'Got the correct structure for the output');

is_deeply($struct->{Outputs}->{outputwithcond1}->{Value}, {Ref => 'XXX'}, "Got the correct value for the output when using a condition");
is_deeply($struct->{Outputs}->{outputwithcond2}->{Value}, { 'Fn::GetAtt' => [ 'XXX', 'InstanceID' ] }, "Got the correct value for the output when using a condition");
is_deeply($struct->{Outputs}->{outputwithcond1}->{Condition}, 'thecond1' , "Got the correct condition for the output when using a condition in the output");
is_deeply($struct->{Outputs}->{outputwithcond2}->{Condition}, 'thecond2' , "Got the correct condition for the output when using a condition in the output");
is_deeply($struct->{Outputs}->{outputwithcondandexport}->{Condition}, 'thecond' , "Got the correct condition for the output when using a condition and an export in the output");
is_deeply($struct->{Outputs}->{outputwithcondandexport}->{Export}->{Name}, 'myexportname' , "Got the correct export for the output when using a condition and an export in the output");

use CloudFormation::DSL qw/Ref GetAtt/;

my $obj_manual_output1 = TestClassAddOutput->new;
$obj_manual_output1->addOutput( myoutput1 => Ref('XXX') );
my $struct_manual_output1 = $obj_manual_output1->as_hashref;
is_deeply($struct_manual_output1->{Outputs}->{myoutput1}->{Value}, {Ref => 'XXX' }, "Got the corret value for the output when creating the output manually with addOutput");
ok(! exists $struct_manual_output1->{Outputs}->{myoutput1}->{Condition}, "Condition parameter does not exist in the output when it is not specified on the construction of the addOutput method"); 

my $obj_manual_output2 = TestClassAddOutput->new;
$obj_manual_output2->addOutput( myoutput2 => GetAtt('XXX', 'InstanceID'), 'Condition', "manualcond2" );
my $struct_manual_output2 = $obj_manual_output2->as_hashref;
is_deeply($struct_manual_output2->{Outputs}->{myoutput2}->{Value}, GetAtt('XXX', 'InstanceID'), "Got the correct value for the output when creating the output manually with addOutput");
is($struct_manual_output2->{Outputs}->{myoutput2}->{Condition}, "manualcond2", "Condition parameter  exist in the output when it is specified on the construction of the Cfn::Output object"); 

my $obj_manual_output3 = TestClassAddOutput->new;
$obj_manual_output3->addOutput( myoutput3 => GetAtt('XXX', 'InstanceID'), Condition => "manualcond3" );
my $struct_manual_output3 = $obj_manual_output3->as_hashref;
is_deeply($struct_manual_output3->{Outputs}->{myoutput3}->{Value}, GetAtt('XXX', 'InstanceID'), "Got the correct value for the output when creating the output manually with addOutput");
is($struct_manual_output3->{Outputs}->{myoutput3}->{Condition}, "manualcond3", "Condition parameter  exist in the output when it is specified in fat-comma form on the construction of the Cfn::Output"); 

my $obj_cfn_output1 = "Cfn::Output"->new( 'Value'  => Ref('XXX') );
my $obj_cfn_output_hash1 = $obj_cfn_output1->as_hashref;
is_deeply($obj_cfn_output_hash1->{Value}, Ref('XXX'), "Got the correct value for the output when creating the output manually when creating a Cfn::Output object directly");
ok(! exists $obj_cfn_output_hash1->{Condition}, "Condition parameter does not exist in the output when it is not specified on the construction of the Cfn::Output object"); 

my $obj_cfn_output2 = "Cfn::Output"->new( 'Value'  => Ref('XXX'), Condition => "manualcond4" );
my $obj_cfn_output_hash2 = $obj_cfn_output2->as_hashref;
is_deeply($obj_cfn_output_hash2->{Value}, Ref('XXX'), "Got the correct value for the output when creating the output manually through a Cfn::Output object directly");
is_deeply($obj_cfn_output_hash2->{Condition}, "manualcond4", "Got the correct value for the condition when creating the output manuallu through a Cfn::Output object directly");

done_testing;
