package XML::Chain;

use warnings;
use strict;
use utf8;

our $VERSION = '0.01';

use Carp qw(croak);
use XML::LibXML;
use Moose;
use MooseX::Aliases;
use Moose::Exporter;
Moose::Exporter->setup_import_methods(
    as_is     => [ 'xc' ],
);

use overload '""' => \&as_string, fallback => 1;

has 'current_elements' => (is => 'rw', isa => 'ArrayRef', default => sub {[]});
has 'document_element' => (is => 'rw', isa => 'HashRef', trigger => sub { $_[0]->dom->setDocumentElement($_[0]->{document_element}->{lxml}) });
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

### xc()

sub xc {
    my ($el_name, @attrs) = @_;

    my $self = __PACKAGE__->new();

    my $ns_uri = {@attrs}->{xmlns} // '';

    my $initial_el = {
        ns   => $ns_uri,
        lxml => $self->_create_element($el_name, $ns_uri, @attrs),
    };
    $self->document_element($initial_el);
    $self->current_elements([$initial_el]);

    return $self;
}

### chained methods

alias c => 'append_and_current';
sub append_and_current {
    my ($self, $el_name, @attrs) = @_;

    my $attrs_ns_uri = {@attrs}->{xmlns};

    $self->current_elements([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            my $ns_uri = $attrs_ns_uri // $el->{ns};
            my $child_el = {
                ns   => $ns_uri,
                lxml => $self->_create_element($el_name, $ns_uri, @attrs),
            };
            $el->{lxml}->appendChild($child_el->{lxml});
            return $child_el;
        })
    ]);

    return $self;
}

alias t => 'append_text';
sub append_text {
    my ($self, $text) = @_;

    $self->_cur_el_iterrate(sub {
        return $_[0]->{lxml}->appendText($text);
    });

    return $self;
}

alias up => 'parent';
sub parent {
    my ($self) = @_;

    $self->current_elements([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            my $parent_el = $el->{lxml}->parentNode;
            return {
                ns   => $parent_el->namespaceURI // '',
                lxml => $parent_el,
            };
        })
    ]);

    return $self;
}

sub root {
    my ($self) = @_;
    $self->current_elements([$self->document_element]);
    return $self;
}

sub find {
    my ($self, $xpath) = @_;

    warn 'TODO';

    return $self;
}

sub children {
    my ($self) = @_;

    $self->current_elements([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            return map { +{
                ns   => $_->namespaceURI,
                lxml => $_,
            } } $el->{lxml}->childNodes;
        })
    ]);

    return $self;
}

sub first {
    my ($self) = @_;

    my ($first) = @{$self->current_elements};
    return $self unless $first;
    $self->current_elements([$first]);

    return $self;
}

sub set_auto_indent {
    return $_[0]->auto_indent(1);
}

sub auto_indent {
    my ($self) = @_;

    warn 'TODO';

    if (@_) {
        my $set_to = shift(@_);

        # TODO set auto indent for current element(s)....
    }

    # TODO return current element(s) auto indent....

    return $self;
}

### methods

alias toString => 'as_string';
sub as_string {
    my ($self) = @_;
    return join('', $self->_cur_el_iterrate(sub { $_[0]->{lxml}->toString }));
}

sub text_content {
    my ($self) = @_;

    my $text = '';
    $self->_cur_el_iterrate(sub {
        my ($el) = @_;
        $text .= $el->{lxml}->textContent;
        return $el;
    });

    return $text;
}

sub as_xml_libxml {
    my ($self) = @_;

    my @elements;
    $self->_cur_el_iterrate(sub {
        my ($el) = @_;
        push(@elements, $el->{lxml});
    });

    return @elements;
}

### helpers

sub _cur_el_iterrate {
    my ($self, $code_ref) = @_;
    croak 'need code ref a argument' unless ref($code_ref) eq 'CODE';
    return map { $code_ref->($_) } @{$self->current_elements};
}

sub _create_element {
    my ($self, $el_name, $ns, @attrs) = @_;

    my $new_element = $self->dom->createElementNS($ns,$el_name);
    while (my $attr_name = shift(@attrs)) {
        my $attr_value = shift(@attrs);
        $new_element->setAttribute($attr_name => $attr_value);
    }
    return $new_element;
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

A factory method creating new L<XML::Chain> object with a document element
as provided in parameters. For example:

    my $icon = xc('i', class => 'icon-download icon-white');
    # <i class="icon-download icon-white"/>

See L<c, append_and_current> for the element parameter description.

=head1 CHAINED METHODS

=head2 c, append_and_current

Appends new element to current elements and changes context to them. New
element is defined in parameters:

    $xc->c('i', class => 'icon-download icon-white')
    # <i class="icon-download icon-white"/>

First parameter is name of the element, then followed by optional element
attributes.

=head2 t, append_text

Appends text to current elements.

    xc('span')->t('some')->t(' ')->t('more text')
    # <span>some more text</span>

First parameter is name of the element, then followed by optional element
attributes.

=head2 root

Sets document element as current element.

    say xc('p')
        ->t('this ')
        ->c('b')
            ->t('is')->up
        ->t(' important!')
        ->root->as_string;
    # <p>this <b>is</b> important!</p>

=head2 up, parent

Traverse current elements and replace them by their parents.

=head2 find

TODO

    say $xc->find('//p/b[@class="less"]')->text_content;

Look-up elements by xpath and set them as current elements.

=head2 children

Set all current elements child nodes as current elements.

=head2 first

Set first current elements as current elements.

=head2 auto_indet / set_auto_indent

TODO

Turn on tidy/auto-indentation of document elements.

=head1 METHODS

=head2 as_string, toString

Returns string representation of current XML elements. Call L<root> before
to get a string representing the whole document.

    $xc->as_string
    $xc->root->as_string

=head2 as_xml_libxml

Returns array of current elements as L<XML::LibXML> objects.

=head2 text_content

Returns text content of all current XML elements.

=head1 CONTRIBUTORS

The following people have contributed to the Sys::Path by committing their
code, sending patches, reporting bugs, asking questions, suggesting useful
advice, nitpicking, chatting on IRC or commenting on my blog (in no particular
order):

    Mohammad S Anwar
    you?

=head1 BUGS

Please report any bugs or feature requests via L<https://github.com/meon/XML-Chain/issues>.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2017 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
