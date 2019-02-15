use Data::Printer;
use Test::More;
#use CCfn;

package TestClass {
  use CloudFormation::DSL;
  use CCfnX::InstanceArgs;
  use CCfnX::DynamicValue;
  # So we can use Test::More in the dynamic values
  use Test::More;

  has params => (is => 'ro', isa => 'CCfnX::InstanceArgs', default => sub { CCfnX::InstanceArgs->new(
    instance_type => 'x1.xlarge',
    region => 'eu-west-1',
    account => 'devel-capside',
    name => 'NAME'
  ); } );

  resource ELB => 'AWS::ElasticLoadBalancing::LoadBalancer', {
    AccessLoggingPolicy => {
      Enabled => 1,
      S3BucketName => CCfnX::DynamicValue->new(Value => sub {
        isa_ok($_[0], 'TestClass', 'A DynamicValue inside a TypedValue recieves as first parameter a reference to the infrastructure');
        return 'the-bucket';
      }), 
    },
    Listeners => [
    ],
  };

  resource Instance => 'AWS::EC2::Instance', sub {
    ImageId => CCfnX::DynamicValue->new(Value => sub { return 'DynamicValue' }),
    InstanceType => Parameter('instance_type'),
    SecurityGroups => [ 'sg-XXXXX' ],
    AvailabilityZone => CCfnX::DynamicValue->new(Value => sub {
      isa_ok($_[0], 'TestClass', 'A DynamicValue recieves as first parameter a reference to the infrastructure');
      return 'eu-west-2'
    }),
    UserData => {
      'Fn::Base64' => {
        'Fn::Join' => [
          '', [
            CCfnX::DynamicValue->new(Value => sub { return 'line 1' }),
            CCfnX::DynamicValue->new(Value => sub { return 'line 2' }),
            CCfnX::DynamicValue->new(Value => sub { 
               CCfnX::DynamicValue->new(Value => sub { return 'dv in a dv' })
            }),
            CCfnX::DynamicValue->new(Value => sub { 
               return ('before dynamic', CCfnX::DynamicValue->new(Value => sub { return 'in middle' }), 'after dynamic');
            }),
          ]
        ]
      }
    }
  };
}

my $obj = TestClass->new;
my $struct = $obj->as_hashref;

cmp_ok($struct->{Resources}{Instance}{Properties}{ImageId}, 'eq', 'DynamicValue', 'Got a correct DynamicValue');
cmp_ok($struct->{Resources}{ELB}{Properties}{AccessLoggingPolicy}{S3BucketName}, 'eq', 'the-bucket', 'Got correct DynamicValue from inside TypedValue');
cmp_ok($struct->{Resources}{Instance}{Properties}{InstanceType}, 'eq', 'x1.xlarge', 'Parameter(instance_type) working correctly');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][0], 'eq', 'line 1', 'userdata dv line 1');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][1], 'eq', 'line 2', 'userdata dv line 2');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][2], 'eq', 'dv in a dv', 'a dynamic value returns a dynamic value and gets resolved');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][3], 'eq', 'before dynamic', 'multiple dynamic returns');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][4], 'eq', 'in middle', 'multiple dynamic returns');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][5], 'eq', 'after dynamic', 'multiple dynamic returns');

done_testing;
