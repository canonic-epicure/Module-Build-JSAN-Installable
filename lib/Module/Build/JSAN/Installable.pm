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
use Data::Dump;


#the only way to install, $self->add_property dont work
__PACKAGE__->add_property('task_name' => 'core');
__PACKAGE__->add_property('static_dir' => 'static');


#================================================================================================================================================================================================================================================
sub new {
    my $pkg = shift;
    my %p = @_;
    $p{metafile} ||= 'META.json';
    if (my $keywords = delete $p{keywords} || delete $p{tags}) {
        if ($p{meta_merge}) {
            $p{meta_merge}->{keywords} = $keywords
        } else {
            $p{meta_merge} = { keywords => $keywords };
        }
    }
    
    my $self = $pkg->SUPER::new(%p);
    

    $self->add_build_element('js');
    
    $self->add_build_element('static');
    
    $self->install_base($self->get_jsan_libroot) unless $self->install_base;
    $self->install_base_relpaths(lib  => 'lib');
    $self->install_base_relpaths(arch => 'arch');
    
    return $self;
}


#================================================================================================================================================================================================================================================
sub get_jsan_libroot {
	
	if($^O eq 'MSWin32') {
		return $ENV{JSANLIB} || 'c:\JSAN';
	} else {
		return $ENV{JSANLIB} || (split /\s+/, $Config{'libspath'})[1] . '/jsan';
	}
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

To build a distribution:

  % perl Build.PL
  % ./Build dist

To install a distribution:

  % perl Build.PL
  % ./Build install


=head1 VERSION

Version 0.01

=cut


=head1 DESCRIPTION

This is a developer aid for creating JSAN distributions. JSAN is the
"JavaScript Archive Network," a JavaScript library akin to CPAN. Visit
L<http://www.openjsan.org/> for details.

Use with caution! This module is considered experimental, its features may be changed without notice.

This module works nearly identically to L<Module::Build::JSAN>, so please refer to
its documentation for additional details.


=head1 DIFFERENCES

=over 1

=item 1. ./Build install

This action will install current distribution in your local JSAN library.
The path to the library is resolved in the following order:
--install_base command-line argument
environment variable JSAN_LIB
either the first directory in $Config{libspath}, followed with '/jsan' (on linux systems)
or 'C:\JSAN' (on Windows)

As a convention, it is recommended, that you configure your local web-server
that way, that http://localhost/jsan will point at the /lib subdirectory of your local
JSAN library. This way you can access any module from it, with URLs like:
"/jsan/Test/Run.js"  

=back

=head1 AUTHOR

Nickolay Platonov, C<< <nplatonov at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-module-build-jsan-installable at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Module-Build-JSAN-Installable>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.



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


