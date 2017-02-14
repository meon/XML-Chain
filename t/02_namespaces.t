#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use open ':std', ':encoding(utf8)';
use Test::Most;

use FindBin qw($Bin);
use lib "$Bin/lib";

use XML::Chain qw(xc);

my $xhtml_xmlns = 'http://www.w3.org/1999/xhtml';

subtest 'default namespace' => sub {
    my $body = xc('body', xmlns => 'http://www.w3.org/1999/xhtml')
                ->c('p')->t('para')
                ->root;
    is($body->as_string, '<body xmlns="'.$xhtml_xmlns.'"><p>para</p></body>', 'root element with default namespace');

    my ($body_el) = $body->first->as_xml_libxml;
    is($body_el->namespaceURI,$xhtml_xmlns,'body has default namespace');

    my ($para_el) = $body->children->first->as_xml_libxml;
    is($para_el->namespaceURI,$xhtml_xmlns,'child has default namespace');
};


done_testing;
