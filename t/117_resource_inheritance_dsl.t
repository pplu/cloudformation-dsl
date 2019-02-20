#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Data::Dumper;
$Data::Dumper::Indent=1;


package SuperClass {
  use CloudFormation::DSL;

  parameter SG1 => 'String', { Default => 'sg-xxxxx' };

  resource SG => 'AWS::EC2::SecurityGroup', {
    VpcId => Ref('VPC'),
    GroupDescription => 'Original description',
    SecurityGroupIngress => [
      SGRule('22', Ref('SG2'), 'tcp'),
      SGRule('-1', '0.0.0.0/0', 'icmp'),
    ],
  };
}

package SuperClassDynamicValue {
  use CloudFormation::DSL;

  parameter SG1 => 'String', { Default => 'sg-xxxxx' };

  resource SG => 'AWS::EC2::SecurityGroup', {
    VpcId => Ref('VPC'),
    GroupDescription => 'Original description',
    SecurityGroupIngress => [
      SGRule('22', Parameter('SG1'), 'tcp'),
    ],
  };
}


#
# Replace behavior: overwrite fixed value with another fixed value
#

{
  package ChildClassReplace {
    use CloudFormation::DSL;
    extends 'SuperClass';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '+VpcId' => 'vpc-xxxx',
      '+GroupDescription' => 'Other description',
      '+SecurityGroupIngress' => [
          SGRule('25', '0.0.0.0/0','tcp'),
      ]
    }
  }

  my $cfn = ChildClassReplace->new();
  my $hash = $cfn->as_hashref;

  is_deeply($hash->{Resources}{SG}{Properties}, {
    'VpcId' => 'vpc-xxxx',
    'SecurityGroupIngress' => [
      {
        'FromPort' => '25',
        'ToPort' => '25',
        'CidrIp' => '0.0.0.0/0',
        'IpProtocol' => 'tcp'
      }
    ],
    'GroupDescription' => 'Other description'
  });
}


#
# Delete behavior: delete fixed value from superclass
#

{
  package ChildClassDelete {
    use CloudFormation::DSL;
    extends 'SuperClass';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '-SecurityGroupIngress' => [],
    }
  }

  my $cfn = ChildClassDelete->new();
  my $hash = $cfn->as_hashref;

  is_deeply($hash->{Resources}{SG}{Properties}, {
    'GroupDescription' => 'Original description',
    'VpcId' => {
      'Ref' => 'VPC'
    }
  });
}


#
# Merge behavior: merge fixed value with another fixed value
#

{

  package ChildClassMerge {
    use CloudFormation::DSL;
    extends 'SuperClass';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '~SecurityGroupIngress' => [
        SGRule('25', '0.0.0.0/0','tcp'),
      ]
    };
  }


  my $cfn = ChildClassMerge->new();
  my $hash = $cfn->as_hashref;

  is_deeply($hash->{Resources}{SG}{Properties}, {
    'SecurityGroupIngress' => [
      {
        'ToPort' => '25',
        'IpProtocol' => 'tcp',
        'CidrIp' => '0.0.0.0/0',
        'FromPort' => '25'
      },
      {
        'SourceSecurityGroupId' => {
          'Ref' => 'SG2'
        },
        'FromPort' => '22',
        'ToPort' => '22',
        'IpProtocol' => 'tcp'
      },
      {
        'FromPort' => -1,
        'CidrIp' => '0.0.0.0/0',
        'IpProtocol' => 'icmp',
        'ToPort' => -1
      }
    ],
    'GroupDescription' => 'Original description',
    'VpcId' => {
      'Ref' => 'VPC'
    }
  });
}


#
# Mix several behaviors in the same resource
#

{

package ChildClassMixed {
  use CloudFormation::DSL;
  extends 'SuperClass';

  resource '+SG' => 'AWS::EC2::SecurityGroup', {
    '+VpcId' => 'vpc-xxxx',
    '-GroupDescription' => 'Other description',
    '+SecurityGroupIngress' => [
      SGRule('25', '0.0.0.0/0','tcp'),
    ]
  };
}


  my $cfn = ChildClassMixed->new();
  my $hash = $cfn->as_hashref();

  is_deeply($hash->{Resources}{SG}{Properties}, {
    'VpcId' => 'vpc-xxxx',
    'SecurityGroupIngress' => [
      {
        'CidrIp' => '0.0.0.0/0',
        'ToPort' => '25',
        'IpProtocol' => 'tcp',
        'FromPort' => '25'
      },
    ]
  });
}


#
# replace behavior with a property from the superclass that is/contains a DynamicValue
#

{
  package ReplaceDynamicValueFromOrigin {
    use CloudFormation::DSL;
    extends 'SuperClassDynamicValue';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '+SecurityGroupIngress' => [
        SGRule('25', '0.0.0.0/0','tcp'),
      ]
    }
  }

  my $cfn = ReplaceDynamicValueFromOrigin->new();
  my $hash = $cfn->as_hashref();

  #print Dumper($hash);
  is_deeply($hash->{Resources}{SG}{Properties}, {
    'VpcId' => {
      'Ref' => 'VPC'
    },
    'SecurityGroupIngress' => [
      {
        'IpProtocol' => 'tcp',
        'FromPort' => '25',
        'ToPort' => '25',
        'CidrIp' => '0.0.0.0/0'
      }
    ],
    'GroupDescription' => 'Original description'
  });
}


#
# Merge bahvior: merge a fixed value with a value that contains a DynamicValue
#

{
  package ChildClassMergeWithDynamicValue {
    use CloudFormation::DSL;
    extends 'SuperClass';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '~SecurityGroupIngress' => [
        SGRule('-1',Parameter('SG1'),'icmp'),
      ]
    };
  }

  my $cfn = ChildClassMergeWithDynamicValue->new();
  my $hash = $cfn->as_hashref();

  is_deeply($hash->{Resources}{SG}{Properties}, {
    'SecurityGroupIngress' => [
      {
        'IpProtocol' => 'icmp',
        'FromPort' => -1,
        'SourceSecurityGroupId' => 'sg-xxxxx',
        'ToPort' => -1
      },
      {
        'IpProtocol' => 'tcp',
        'FromPort' => '22',
        'SourceSecurityGroupId' => {
          'Ref' => 'SG2'
        },
        'ToPort' => '22'
      },
      {
        'IpProtocol' => 'icmp',
        'FromPort' => -1,
        'ToPort' => -1,
        'CidrIp' => '0.0.0.0/0'
      }
    ],
    'GroupDescription' => 'Original description',
    'VpcId' => {
      'Ref' => 'VPC'
    }
  });
}


#
# Replace behavior: overwrite fixed value with a DynamicValue
#

{
  package ChildClassReplaceWithDynamicValue {
    use CloudFormation::DSL;
    extends 'SuperClass';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '+SecurityGroupIngress' => [
        SGRule('-1',Parameter('SG1'),'icmp'),
      ]
    };
  }

  my $cfn = ChildClassReplaceWithDynamicValue->new();
  my $hash = $cfn->as_hashref();

  is_deeply($hash->{Resources}{SG}{Properties}, {
    'VpcId' => {
      'Ref' => 'VPC'
    },
    'SecurityGroupIngress' => [
      {
        'ToPort' => -1,
        'SourceSecurityGroupId' => 'sg-xxxxx',
        'IpProtocol' => 'icmp',
        'FromPort' => -1
      }
    ],
    'GroupDescription' => 'Original description'
  });
}


#
# Merge behavior: merge a DynamicValue from the super class with a fixed value
#

{
  package MergeDynamicValueFromOrigin {
    use CloudFormation::DSL;
    extends 'SuperClassDynamicValue';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '~SecurityGroupIngress' => [
        SGRule('25', '0.0.0.0/0','tcp'),
      ]
    }
  }

  my $cfn = MergeDynamicValueFromOrigin->new();
  my $hash = $cfn->as_hashref();
  is_deeply($hash->{Resources}{SG}{Properties}, {
    'SecurityGroupIngress' => [
      {
        'IpProtocol' => 'tcp',
        'FromPort' => '25',
        'CidrIp' => '0.0.0.0/0',
        'ToPort' => '25'
      },
      {
        'ToPort' => '22',
        'FromPort' => '22',
        'IpProtocol' => 'tcp',
        'SourceSecurityGroupId' => 'sg-xxxxx'
      }
    ],
    'GroupDescription' => 'Original description',
    'VpcId' => {
      'Ref' => 'VPC'
    }
  });
}


#
# Merge behavior: merge a DynamicValue from the superclass with another
# DynamicValue (parameter)
#

{
  package MergeDynamicValueFromOrigin2 {
    use CloudFormation::DSL;
    extends 'SuperClassDynamicValue';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '~SecurityGroupIngress' => [
        SGRule('12345', '0.0.0.0/0','tcp'),
      ]
    }
  }

  my $cfn = MergeDynamicValueFromOrigin2->new();
  my $hash = $cfn->as_hashref();
  is_deeply($hash->{Resources}{SG}{Properties}, {
    'SecurityGroupIngress' => [
      {
        'IpProtocol' => 'tcp',
        'FromPort' => '12345',
        'CidrIp' => '0.0.0.0/0',
        'ToPort' => '12345'
      },
      {
        'ToPort' => '22',
        'FromPort' => '22',
        'IpProtocol' => 'tcp',
        'SourceSecurityGroupId' => 'sg-xxxxx'
      }
    ],
    'GroupDescription' => 'Original description',
    'VpcId' => {
      'Ref' => 'VPC'
    }
  });
}


#
# Merge behavior: merge in a deeper level
#
{

  package DeeperMergeSuperClass {
    use CloudFormation::DSL;

    resource Role => 'AWS::IAM::Role', {
      Path => '/',
      AssumeRolePolicyDocument => {
        Statement => [{
          Action => [ 'sts:AssumeRole' ],
          Effect => 'Allow',
          Principal => { Service => [ 'ec2.amazonaws.com' ] }
        }],
      },
      Policies => [{
        PolicyName => 'MyPolicy',
        PolicyDocument => {
          Statement => [{
            Effect => 'Allow',
            Resource => '*',
            Action => ["SomeService:SomeAction"]
          }],
        }
      }]
    };
  }

  package DeeperMergeChildClass {
    use CloudFormation::DSL;
    extends 'DeeperMergeSuperClass';

    resource '+Role' => 'AWS::IAM::Role', {
      '~Policies' => [{
        PolicyName => 'OtherPolicy',
        PolicyDocument => {
          Statement => [{
            Effect => 'Allow',
            Resource => '*',
            Action => ["SomeOtherService:SomeOtherAction"]
          }],
        }
      }]
    };
  }

  my $cfn = DeeperMergeChildClass->new();
  my $hash = $cfn->as_hashref();
  is_deeply($hash->{Resources}{Role}{Properties}{Policies}, [
      {
        'PolicyName' => 'OtherPolicy',
        'PolicyDocument' => {
          'Statement' => [
            {
              'Action' => [
                'SomeOtherService:SomeOtherAction'
              ],
              'Effect' => 'Allow',
              'Resource' => '*'
            }
          ]
        }
      },
      {
        'PolicyDocument' => {
          'Statement' => [
            {
              'Action' => [
                'SomeService:SomeAction'
              ],
              'Effect' => 'Allow',
              'Resource' => '*'
            }
          ]
        },
        'PolicyName' => 'MyPolicy'
      }
  ]);
}

#
# Merge hashes
#

{
  package SuperClassWithHashProp {
    use CloudFormation::DSL;

    resource 'ParameterGroup' => 'AWS::RDS::DBParameterGroup', {
      Description => 'X',
      Family => 'Y',
      Parameters => {
        	key1 => 'key1value1',
        }
    };

  };

  package ChildClassMergeHash {
    use CloudFormation::DSL;
    extends 'SuperClassWithHashProp';

    resource '+ParameterGroup' => 'AWS::RDS::DBParameterGroup', {
      '~Parameters' => {
          key1 => 'key1value2',
          key2 => 'key2value1',
        }
    };

  };

  my $cfn = ChildClassMergeHash->new();
  my $hash = $cfn->as_hashref();
  is_deeply($hash->{Resources}{ParameterGroup}{Properties}{Parameters}, {
    key1 => 'key1value2',
    key2 => 'key2value1',
  });
}

#
# Inheritance in the extra hash of attributes
#

{
  package SuperClassWithExtra {
    use CloudFormation::DSL;

    resource SG => 'AWS::EC2::SecurityGroup', {
      VpcId => Ref('VPC'),
      GroupDescription => 'Original description',
      SecurityGroupIngress => [
        SGRule('22', Ref('SG2'), 'tcp'),
        SGRule('-1', '0.0.0.0/0', 'icmp'),
      ],
    }, {
      UpdatePolicy => {
        AutoScalingRollingUpdate => {
          MinInstancesInService => "1",
          MaxBatchSize => "2",
          WaitOnResourceSignals => "true",
          PauseTime => "PT10M"
        },
      },
      CreationPolicy => {
        ResourceSignal => {
          Count => Ref('ResourceSignalsOnCreate'),
          Timeout => 'PT10M'
        },
      }
    };
  };

  package ChildClassWithExtra {
    use CloudFormation::DSL;
    extends 'SuperClassWithExtra';

    resource '+SG' => 'AWS::EC2::SecurityGroup', {
      '+VpcId' => 'vpc-xyz',
    },
    {
      '+UpdatePolicy' => {
        AutoScalingRollingUpdate => {
          MinInstancesInService => "3",
          MaxBatchSize => "5",
          WaitOnResourceSignals => "true",
          PauseTime => "PT20M"
        }
      },
      '+Condition' => 'Condition1',
    };
  };

  my $cfn = ChildClassWithExtra->new();
  my $hash = $cfn->as_hashref;
  is_deeply($hash->{Resources}{SG}{UpdatePolicy}, {
    'AutoScalingRollingUpdate' => {
      'PauseTime' => 'PT20M',
      'MaxBatchSize' => '5',
      'WaitOnResourceSignals' => 'true',
      'MinInstancesInService' => '3'
    }
  });
  is_deeply($hash->{Resources}{SG}{CreationPolicy}, {
    'ResourceSignal' => {
      'Count' => {
        'Ref' => 'ResourceSignalsOnCreate'
      },
      'Timeout' => 'PT10M'
    }
  });
  is($hash->{Resources}{SG}{Condition}, "Condition1", "Condition added with inheritance DSL");
}

done_testing();
