package Module::Build::JSAN::Installable;

use strict;
use vars qw($VERSION @ISA);

$VERSION = '0.01';

use Module::Build::JSAN;
@ISA = qw(Module::Build::JSAN);

use File::Spec::Functions qw(catdir catfile);
use File::Basename qw(dirname);

use Path::Class;
use Config;
use JSON;


#XXX for debugging
#use Data::Dump;


__PACKAGE__->add_property('task_name' => 'core');
__PACKAGE__->add_property('static_dir' => 'static');


#================================================================================================================================================================================================================================================
sub new {
    my $self = shift->SUPER::new(@_);

    $self->add_build_element('js');
    
    $self->add_build_element('static');
    
    $self->install_base($self->get_jsan_libroot) unless $self->install_base;
    $self->install_base_relpaths(lib  => 'lib');
    $self->install_base_relpaths(arch => 'arch');
    
    return $self;
}


#================================================================================================================================================================================================================================================
sub get_jsan_libroot {
	return $ENV{JSANLIB} || ($^O eq 'MSWin32') ? 'c:\JSAN' : (split /\s+/, $Config{'libspath'})[1] . '/jsan';
}


#================================================================================================================================================================================================================================================
# workaround for http://rt.cpan.org/Public/Bug/Display.html?id=43515
# should be 'our', because 'resume' calls with package name
our $skip_install_paths = 0;

sub resume {
    $skip_install_paths = 1;
    my $res = shift->SUPER::resume(@_);
    $skip_install_paths = 0;
    
    return $res;
}


sub _set_install_paths {
    return if $skip_install_paths;
    
    shift->SUPER::_set_install_paths(@_);
}
# eof workaround 



#================================================================================================================================================================================================================================================
sub process_static_files {
	my $self = shift;
	
	my $static_dir = $self->static_dir;
  
  	return if !-d $static_dir;
  
  	#find all files except directories
  	my $files = $self->rscan_dir($static_dir, sub {
  		!-d $_
  	});
  	
	foreach my $file (@$files) {
		$self->copy_if_modified(from => $file, to => File::Spec->catfile($self->blib, 'lib', $self->dist_name_as_dir, $file) );
	}
  	
}


#================================================================================================================================================================================================================================================
sub ACTION_install {
    my $self = shift;
    
    require ExtUtils::Install;
    
    $self->depends_on('build');
    
    my $map = $self->install_map;
    my $dist_name = quotemeta $self->dist_name();
    
    #trying to be cross-platform
    my $dist_name_to_dir = catdir( split(/\./, $self->dist_name()) );
    
    $map->{'write'} =~ s/$dist_name/$dist_name_to_dir/;
    
    ExtUtils::Install::install($map, !$self->quiet, 0, $self->{args}{uninst}||0);
}


#================================================================================================================================================================================================================================================
sub dist_name_as_dir {
	return split(/\./, shift->dist_name());
}


#================================================================================================================================================================================================================================================
sub comp_to_filename {
	my ($self, $comp) = @_;
	
    my @dirs = split /\./, $comp;
    $dirs[-1] .= '.js';
	
	return file('lib', @dirs);
}


#================================================================================================================================================================================================================================================
sub ACTION_task {
    my $self = shift;
    
	my $components = file('Components.JS')->slurp;

	#removing // style comments
	$components =~ s!//.*$!!gm;

	#extracting from most outer {} brackets
	$components =~ m/(\{.*\})/s;
	$components = $1;

	my $deploys = decode_json $components;
	
	#expanding +deploy_variant entries
	foreach my $deploy (keys(%$deploys)) {
		
		$deploys->{$deploy} = [ map { 
			
			/^\+(.+)/ ? @{$deploys->{$1}} : $_;
			
		} @{$deploys->{$deploy}} ];
	}

	$self->concatenate_for_task($deploys, $self->task_name);
}


#================================================================================================================================================================================================================================================
sub concatenate_for_task {
    my ($self, $deploys, $task_name) = @_;
    
    if ($task_name eq 'all') {
    	
    	foreach my $deploy (keys(%$deploys)) {
    		$self->concatenate_for_task($deploys, $deploy);  	
    	}
    
    } else {
	    my $components = $deploys->{$task_name};
	    die "Invalid task name: [$task_name]" unless $components;
	    
	    my @dist_dirs = split /\./, $self->dist_name();
	    push @dist_dirs, $task_name;
	    $dist_dirs[-1] .= '.js';
	    
	    my $bundle_file = file('lib', 'Task', @dist_dirs);
	    $bundle_file->dir()->mkpath();
	    
	    my $bundle_fh = $bundle_file->openw(); 
	    
	    foreach my $comp (@$components) {
	        print $bundle_fh $self->comp_to_filename($comp)->slurp . ";\n";
	    }
	    
	    $bundle_fh->close();
    };
}


#================================================================================================================================================================================================================================================
sub ACTION_test {
	my ($self) = @_;
	
	my $result = (system 'jsan-prove') >> 8;
	
	if ($result == 1) {
		print "All tests successfull\n";
	} else {
		print "There were failures\n";
	}
}


1; # End of Module::Build::JSAN::Installable

__END__

=head1 NAME

Module::Build::JSAN::Installable - Build JavaScript distributions for JSAN, which can be installed locally

=head1 SYNOPSIS

In F<Build.PL>:

  use Module::Build::JSAN::Installable;

  my $build = Module::Build::JSAN::Installable->new(
      module_name    => 'Foo.Bar',
      license        => 'perl',
      keywords       => [qw(Foo Bar pithyness)],
      requires     => {
          'JSAN'     => 0.10,
          'Baz.Quux' => 0.02,
      },
      build_requires => {
          'Test.Simple' => 0.20,
      },
      
      static_dir => 'assets'
  );

  $build->create_build_script;


To build, test and install a distribution:

  % perl Build.PL
  % ./Build
  % ./Build test  
  % ./Build install


In F<Components.js>:

  COMPONENTS = {
      
      "kernel" : [
          "JooseX.Namespace.Depended.Manager",
          "JooseX.Namespace.Depended.Resource",
          
          "JooseX.Namespace.Depended.Materialize.Code"
      ],
      
      
      "web" : [
          "+kernel",
      
          "JooseX.Namespace.Depended.Transport.AjaxAsync",
          "JooseX.Namespace.Depended.Transport.AjaxSync",
          "JooseX.Namespace.Depended.Transport.ScriptTag",
          
          "JooseX.Namespace.Depended.Resource.URL",
          "JooseX.Namespace.Depended.Resource.URL.JS",
          "JooseX.Namespace.Depended.Resource.JS",
          "JooseX.Namespace.Depended.Resource.JS.External",
          
          //should be the last        
          "JooseX.Namespace.Depended"
      ],
  	
      
      "core" : [
          "+web"
      ],
      
      
      "serverjs" : [
          "+kernel",
          
          "JooseX.Namespace.Depended.Transport.Require",
          "JooseX.Namespace.Depended.Resource.Require",
          
          //should be the last
          "JooseX.Namespace.Depended"
      ]
  	
  } 
	


=head1 VERSION

Version 0.01

=cut


=head1 DESCRIPTION

This is a developer aid for creating JSAN distributions. JSAN is the
"JavaScript Archive Network," a JavaScript library akin to CPAN. Visit
L<http://www.openjsan.org/> for details.

This module works nearly identically to L<Module::Build::JSAN>, so please refer to
its documentation for additional details.


=head1 DIFFERENCES

=over 4

=item 1 ./Build install

This action will install current distribution in your local JSAN library.
The path to the library is resolved in the following order:


- B<--install_base> command-line argument

- environment variable B<JSAN_LIB>

- Either the first directory in B<$Config{libspath}>, followed with '/jsan' (probably '/usr/local/lib' on linux systems)
or B<'C:\JSAN'> (on Windows)


As a convention, it is recommended, that you configure your local web-server
that way, that B</jsan> will point at the B</lib> subdirectory of your local
JSAN library. This way you can access any module from it, with URLs like:
B<'/jsan/Test/Run.js'>  


=item 1 ./Build task [--task_name=foo]

This action will build a specific concatenated version (task) of current distribution.
Default task name is B<'core'>, task name can be specified with B<--task_name> command line option.

Information about tasks is stored in the B<Components.JS> file in the root of distribution.
See the Synposys for example of B<Components.JS>. 

After concatenation, resulting file is placed on the following path: B</lib/Task/Distribution/Name/sample_task.js>, 
considering the name of your distribution was B<Distribution::Name> and the task name was B<sample_task>


=item 1 ./Build test

This action relies on not yet release JSAN::Prove module, stay tuned for further updates.

=back


=head1 Static files handling

Under static files we'll assume any files other than javascript (*.js). Typically those are *.css files and images (*.jpg, *.gif, *.png etc).

All static files should be placed in the 'static directory'. Default name for static directory is B<'/static'>. 
Alternative name can be specified with B<static_dir> configuration parameter (see Synopsis). Static directory can be organized in any way you prefere.

Lets assume you have the following distribution structure:

  /lib/Distribution/Name.js
  /static/css/style1.css 
  /static/img/image1.png

After building (B<./Build>) it will be processed as:

  /blib/lib/Distribution/Name.js
  /blib/lib/Distribution/Name/static/css/style1.css 
  /blib/lib/Distribution/Name/static/img/image1.png

During installation (B<./Build install>) the whole 'blib' tree along with static files will be installed in your local library.


=head1 AUTHOR

Nickolay Platonov, C<< <nplatonov at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-module-build-jsan-installable at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Module-Build-JSAN-Installable>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SEE ALSO

=over

=item Examples of installable JSAN distributions 

L<http://github.com/SamuraiJack/JooseX-Namespace-Depended/tree>

L<http://github.com/SamuraiJack/joosex-bridge-ext/tree>

=item L<http://www.openjsan.org/>

Home of the JavaScript Archive Network.

=item L<http://code.google.com/p/joose-js/>

Joose - Moose for JavaScript

=item L<http://github.com/SamuraiJack/test.run/tree>

Yet another testing platform for JavaScript

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Module::Build::JSAN::Installable


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Build-JSAN-Installable>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Module-Build-JSAN-Installable>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Module-Build-JSAN-Installable>

=item * Search CPAN

L<http://search.cpan.org/dist/Module-Build-JSAN-Installable/>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to David Wheeler for his excelent Module::Build::JSAN, on top of which this module is built.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Nickolay Platonov, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut


