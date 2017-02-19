package XML::Chain;

use warnings;
use strict;
use utf8;
use 5.010;

our $VERSION = '0.02';

use XML::LibXML;
use XML::Chain::Selector;
use XML::Chain::Element;
use Carp qw(croak);
use Moose;
use Moose::Exporter;
Moose::Exporter->setup_import_methods(
    as_is     => [ 'xc' ],
);

has 'document_element' => (
    is      => 'rw',
    isa     => 'XML::Chain::Element',
    trigger => sub {
        $_[0]->dom->setDocumentElement($_[0]->{document_element}->{lxml});
    }
);
has 'dom' => (is => 'rw', isa => 'XML::LibXML::Document', lazy_build => 1);
has '_xml_libxml' => (
    is      => 'rw',
    isa     => 'XML::LibXML',
    lazy    => 1,
    default => sub {XML::LibXML->new}
);

sub _build_dom {
    my ($self) = @_;
    return $self->_xml_libxml->createDocument("1.0", "UTF-8");
}

sub xc {
    my ($el_name, @attrs) = @_;

    my $self = __PACKAGE__->new();

    my $ns_uri = {@attrs}->{xmlns} // '';

    my $initial_el = $self->_create_element($el_name, $ns_uri, @attrs);
    $self->document_element($initial_el);
    return XML::Chain::Selector->new(
        current_elements => [$initial_el],
        xc               => $self,
    );
}

sub _create_element {
    my ($self, $el_name, $ns, @attrs) = @_;

    my $new_element = $self->dom->createElementNS($ns,$el_name);
    while (my $attr_name = shift(@attrs)) {
        my $attr_value = shift(@attrs);
        $new_element->setAttribute($attr_name => $attr_value);
    }
    return $self->_xc_el($new_element);
}

sub _xc_el {
    my ($self, $el) = @_;
    croak 'need element as argument' unless defined($el);

    my $eid = $el->unique_key;
    return $self->{_xc_el}->{$eid} //= XML::Chain::Element->new(
        ns   => $el->namespaceURI // '',
        lxml => $el,
        xc   => $self,
    );
}

1;


__END__

=encoding utf8

=head1 NAME

XML::Chain - chained way of manipulating and inspecting XML documents

=head1 SYNOPSIS

    use XML::Chain qw(xc);

    # basics
    my $div = xc('div', class => 'pretty')
                ->c('h1')->t('hello')
                ->up
                ->c('p', class => 'intro')->t('world!');
    say $div->as_string;
    # <div class="pretty"><h1>hello</h1><p class="intro">world!</p></div>

=head1 DESCRIPTION

☢ at this moment L<XML::Chain> is in early prototype phase ☢

This module provides fast and easy way to create and manipulate XML elements
via set of chained method calls.

=head1 EXPORTS

=head2 xc

Exported factory method creating new L<XML::Chain::Selector> object with
a document element as provided in parameters. For example:

    my $icon = xc('i', class => 'icon-download icon-white');
    # <i class="icon-download icon-white"/>

See L<XML::Chain::Selector/c, append_and_current> for the element parameter
description and L<XML::Chain::Selector/CHAINED METHODS> for methods of
returned object.

=head1 CONTRIBUTORS & CREDITS

Initially inspired by Strophe.Builder, then also by jQuery.

The following people have contributed to the XML::Chain by committing their
code, sending patches, reporting bugs, asking questions, suggesting useful
advice, nitpicking, chatting on IRC or commenting on my blog (in no particular
order):

    Mohammad S Anwar
    you?

Also thanks to my current day-job-employer L<http://geizhals.at/>.

=head1 BUGS

Please report any bugs or feature requests via L<https://github.com/meon/XML-Chain/issues>.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2017 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
