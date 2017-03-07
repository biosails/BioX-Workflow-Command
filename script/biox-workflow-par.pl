#!perl

use utf8;
package Main;

use BioX::Workflow::Command;

use BioX::Workflow::Command::run;
use BioX::Workflow::Command::new;
use BioX::Workflow::Command::add;

BioX::Workflow::Command->new_with_command()->execute();
