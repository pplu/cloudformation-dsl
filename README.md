# NAME

CloudFormation::DSL - A Domain Specific Language for creating CloudFormation templates

# SYNOPSIS

    package MyStack {
      use CloudFormation::DSL;

      resource Instance1 => 'AWS::EC2::Instance', {
        ImageId => 'ami-12345',
      };

      output IP => GetAtt('Instance1', 'PublicIp');
    }

    my $s1 = MyStack->new;
    say "Resource Count: " . $s1->ResourceCount;
    print $s1->as_hashref;

# DESCRIPTION

CloudFormation is a great AWS service for automating infrastructure creation. You can get a better
grasp of what CloudFormation does and tries to solve here: [https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)

CloudFormation::DSL is a "framework" for writing CloudFormation and addressing some of its shortcomings.
It lets you express CloudFormation templates in an easier fashion, with a more forgiving syntax 
than the standard JSON or YAML syntaxes that CloudFormation supports. It also eases authoring some 
complex CloudFormation patterns.

You can think of it as a preprocessor that generates CloudFormation documents.

CloudFormation::DSL builds on the idea that the information in a CloudFormation template can be
expressed as a class. After all, a class is a template for an object! Since we represent templates 
as classes, we can instance those classes, manipulate and query them. An instance of a class has
an `as_json` method that once called generates the CloudFormation document that can be sent to
the CloudFormation service.

CloudFormation::DSL builds upon existing layers:

[Cfn](https://metacpan.org/pod/Cfn): Each `CloudDeploy::DSL` class is a Cfn subclass. This means that the object model that 
Cfn provides is accessible from `CloudDeploy::DSL`.

[Moose](https://metacpan.org/pod/Moose) and [Perl](https://metacpan.org/pod/Perl): `CloudDeploy::DSL` builds upon Moose's (An Object Orientation framework for Perl)
and Perl's ability to add syntax to the language. This let's us declare keywords like `resource` 
or `paramter` so you can write your CloudFormation templates in a faster way. This is just an implementation
detail: you don't need to know Moose or Perl to use `CloudFormation::DSL`.

CloudFormation::DSL brings you full object orientation to your CloudFormation template authoring: you
can create base classes, inherit, override and specialize.

Enough chit-chat: let's see the action:

# Writing a class

Start a file named \`MyCfn.pm\`

    package MyCfn {
      use CloudFormation::DSL;
    }
    1;

You now have a class that represents a template without resources. Now we'll add stuff with
the following keywords:

## resource Name => 'TYPE', { ... Properties ... };

    package MyCfn {
      use CloudFormation::DSL;

      resource User1 => 'AWS::IAM::User', {
        Path => "/",
      };
    }

The resource keyword declares a CloudFormation resource of type `TYPE`. The supported types
are available in the `Cfn::Resource` namespace. This piece of code generates the following
CloudFormation:

    {
      "Resources": {
        "User1": {
          "Type": "AWS::IAM::User",
          "Properties": {
            "Path": "/"
          }
        }
      }
    }

Note a couple of things that the DSL is doing for us:

`User1` doesn't have to be quoted. Perls "fat comma" automatically quotes it for us!

You could write:

    resource 'User1' => 'AWS::IAM::User', { ... };

if you wanted. You could also use double quotes:

    resource "User1" => 'AWS::IAM::User', { ... };

You actually need to do this if the resource name has special characters. 

Note that we specify the properties just after the object in a Key / Value fashion.
We use Perls Hashrefs to represent these Key/Value structures. The Keys are the same
keys that we would use in the `"Properties"` object in a CloudFormation template. The
values can be Perl strings `"myvalue"`, Perl numbers `42`, bareword booleans `true` 
or `false` and also CloudFormation functions like `{ Ref =` 'LogicalId' }> and 
`{ 'Fn::GetAtt' =`  \[ 'LogicalId', 'AttributeName' \] }> as Perl HashRefs. If you think 
this is typing too much, please read the "shortcuts" section. You don't have to type
`"Properties"`, and these go first, since 99% of the time we write resources, we
write their properties.

Note that in HashRefs we can leave trailing commas:

    { Path => '/', }

is valid, while in JSON

    { "Path": "/", }

isn't valid.

The DSL is also helping us assuring that AWS::IAM::User is a valid resource type. If we
don't use a supported resource type, we will get an error. This is also true for its
properties. The `AWS::IAM::User` object has a property called `Path`. If we had a
typo in the `Path` property, we would get an error. If we didn't define a required property
we get an error. If we used a wrong value: we get an error.

## resource Name => 'TYPE', { ... Properties ... }, { ... Resource Attributes ... }

If we want to configure resource properties like `DependsOn` or `DeletionPolicy`
we can do so passing a fourth element to our `resource` statement:

    resource "User1" => 'AWS::IAM::User', { ... }, { DeletionPolicy => 'Retain' };

The DSL will verify that the DeletionPolicy is a permitted value in CloudFormation.

## output Name => ...;

This will declare an output in our CloudFormation template.

    package MyCfn {
      use CloudFormation::DSL;

      resource User1 => 'AWS::IAM::User', {
        Path => "/"
      };

      output IAMUser => Ref('User1');
    }

Note that the name of the output doesn't need to be quoted (just like in with the
`resource` keyword. The value for an output is the same ones that CloudFormation supports.
In the example we're using a shortcut to specify a CloudFormation Ref function. We could
have wrote:

    output IAMUser => { Ref => 'User1' };

The two are equivalent to the following CloudFormation JSON:

    {
      "Outputs": {
        "IAMUser": {
          "Value": { "Ref": "User1" }
        }
      }
    }

## output Name => ..., { ... Output properties ... };

We can also specify extra properties for the output `Description`,

    output IAMUser => { Ref => 'User1' }, {
      Description => 'The name of the IAM user',
    };

Will generate:

    {
      "Outputs": {
        "IAMUser": {
          "Value": { "Ref": "User1" },
          "Description": "The name of the IAM user"
        }
      }
    }

## parameter Name => 'TYPE', { ... Properties ... }

The `parameter` keyword adds a CloudFormation parameter to the template.

    parameter IAMPath => 'String',

Generates:

    {
      "Parameters": {
        "IAMPath": {
          "Type": "String"
        }
      }
    }

## parameter Name => 'TYPE', { ... Properties ... }

We can also specify parameter properties like `Default`,
`NoEcho`, `MaxLength`, etc.

    parameter IAMPath => 'String', {
      Default => '/',
      MazLength => 32,
    };

Generates:

    {
      "Parameters": {
        "IAMPath": {
          "Type": "String",
          "Default": "/",
          "MaxLength": 32
        }
      }
    }

## condition Name => ...;

Adds a condition to the template

## mapping Name => { }

Adds a CloudFormation mapping with a specific name

## metadata

Adds a metadata key to the template

## transform

Adds a transform to the template

## stack\_version

# Shortcuts

## Ref('LogicalId')

is a shorthand way to write `{ Ref =` 'LogicalId' }>

It writes `{"Ref":"LogicalId"}` in the CloudFormation template.

## GetAtt('LogicalId', 'AttributeName')

is a shorthand way to write

## Parameter('ParameterName')

is a shorthand way of referencing a parameter that doesn't get passed to CloudFormation. 

## Tag($key, $value)

is a shorhand way of writing the values that most `Tag` attributes of resources expect:

    Tag('Owner', 'me')

gets converted to

    { "Key": "Owner", "Value": "me" }

in CloudFormation

An example of usage would be:

    resource Subnet1 => 'AWS::EC2::Subnet', {
      VpcId => Ref('Vpc'),
      CidrBlock => '10.0.0.0/24',
      Tags => [ Tag('Owner', 'me'), Tag('BU', 'sales') ],
    };

## Attribute('AttributeName')

is a shorthand way of referencing an instance attribute. This is for advanced use. See
the "Instance Attributes" section.

## UserData($string)

is a shorthand way to import the contents of a file in "UserData" format:

### TieFighters

Tiefighters are sequences of `#-#...#-#` that can be found inside the files
that the UserData keyword converts to the

#### #-#LogicalId#-#

Inserts a Ref('LogicalId')

#### #-#LogicalId->Attribute#-#

Inserts a GetAtt('LogicalId', 'Attribute') 

#### #-#Parameter(ParamName)#-#

Inserts a Parameter

#### #-#Attribute(ParamName)#-#

Inserts an Attribute value

## CfString($string)

is a shorthand way to write a string that has gets tiefighters interpreted

## Json($json\_string)

will convert a JSON string into a HashRef

# Networking shortcuts

## ELBListener($lbport, $lbprotocol\[, $instance\_port\[, $instance\_protocol\]\])

is a shorthand way of writing an ELB Listener. It can be used in many ways:

`ELBListener(80, 'HTTP')` will forward traffic from port 80 of the ELB to port 80 on the backends

`ELBListener(80, 'HTTP', 3000)` will forward traffic from port 80 of the ELB to port 3000 on the 
backends

`ELBListener(443, 'HTTPS', 5000, 'HTTP') will do SSL offloading on the ELB, forwarding to port 
5000 HTTP on the backends`

## TCPELBListener($lbport\[, $instance\_port\])

## SGRule($port, $to, $desc)

## SGRule($port, $to, $proto, $desc)

## SGEgressRule

# Getting the most out of the DSL

# Inheritance

You can use inheritance primitives to structure your infrastructure into reusable modules

    package MyBaseClass {
      use CloudFormation::DSL;

      resource I1 => 'AWS::EC2::Instance', {
        ImageId => SpecifyInSubClass,
        SecurityGroups => [ Ref('SG' ],
      };
      resource SG => 'AWS::EC2::SecurityGroup, {
        ...
      };
    }
    package SubClass1 {
      use CloudFormation::DSL;
      extends 'MyBaseClass';
      resource I1 => 'AWS::IAM::User', {
        ImageId => 'ami-XXXX',
      };
    }

## SpecifyInSubClass

Use `SpecifyInSubClass` to force the user to overwrite this value in a subclass:

    package MyBase {
      use CloudFormation::DSL;

      resource User1 => 'AWS::IAM::User', {
        Path => SpecifyInSubclass,
      };
    }

If MyBase is instanced, an error will be thrown. The value can be overwritten in 
subclasses:

    package MySubClass {
      use CloudFormation::DSL;
      extends 'MyBase';

      resource '+User1' => 'AWS::IAM::User', {
        Path => '/',
      };
    }

# Attachments

## attachment 

Adds an attachment to the template

# Extending the DSL

# Instance Attributes

# SEE ALSO

[Cfn](https://metacpan.org/pod/Cfn)

[https://docs.aws.amazon.com/es\_es/AWSCloudFormation/latest/UserGuide/Welcome.html](https://docs.aws.amazon.com/es_es/AWSCloudFormation/latest/UserGuide/Welcome.html)

# AUTHOR

    Jose Luis Martinez
    CAPSiDE
    jlmartinez@capside.com

# Contributions

Thanks to Sergi Pruneda, Miquel Ruiz, Luis Alberto Gimenez, Eleatzar Colomer, Oriol Soriano, 
Roi Vazquez for years of work on this module.

# BUGS and SOURCE

The source code is located here: [https://github.com/pplu/cloudformation-dsl](https://github.com/pplu/cloudformation-dsl)

Please report bugs to: [https://github.com/pplu/cfn-perl/cloudformation-dsl](https://github.com/pplu/cfn-perl/cloudformation-dsl)

# COPYRIGHT and LICENSE

Copyright (c) 2013 by CAPSiDE
This code is distributed under the Apache 2 License. The full text of the 
license can be found in the LICENSE file included with this module.

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 990:

    Unterminated C<...> sequence
