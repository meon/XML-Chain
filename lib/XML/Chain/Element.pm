package XML::Chain::Element;

use warnings;
use strict;
use utf8;
use 5.010;

our $VERSION = '0.02';

use Moose;
use MooseX::Aliases;
use Carp qw(croak);

use overload '""' => \&as_string, fallback => 1;

has 'ns' => (is => 'rw', isa => 'Str', required => 1);
has 'lxml' => (is => 'rw', isa => 'XML::LibXML::Node', required => 1);
has 'auto_indent' => (is => 'rw',);
has '_xc' => (is => 'rw', isa => 'XML::Chain', required => 1, weak_ref => 1);

my @selector_methods = qw(
    c append_and_current
    t append_text
    up parent
    root document_element
    find
    children
    first
    auto_indent
    toString as_string
    text_content
    size count
    single
);

my $meta = __PACKAGE__->meta;

# generate selector methods
foreach my $sel_method (@selector_methods) {
    $meta->add_method(
        $sel_method => sub {
            my ($self, @attrs) = @_;
            $self->_selector->$sel_method(@attrs);
        }
    );
}

sub as_xml_libxml { return $_[0]->{lxml}; }

sub _selector {
    my ($self) = @_;
    return XML::Chain::Selector->new(
        current_elements => [$self],
        _xc              => $self->{_xc},
    );
}

1;


__END__

=encoding utf8

=head1 NAME

XML::Chain::Element - helper class for XML::Chain representing single element

=head1 SYNOPSIS

    xc('body')->c(h1)->t('title')->root

=head1 DESCRIPTION

Returned by L<XML::Chain::Selector/single> call.

=head1 METHODS

=head2 as_xml_libxml

Returns L<XML::LibXML::Element> object.

=head2 XML::Chain::Selector methods

All of the L<XML::Chain::Selector> methods works too.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2017 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
