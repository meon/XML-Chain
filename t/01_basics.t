#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use open ':std', ':encoding(utf8)';
use Test::Most;

use FindBin qw($Bin);
use lib "$Bin/lib";

use XML::Chain qw(xc);

subtest 'xc()' => sub {
    my $body = xc('body');
    isa_ok($body, 'XML::Chain', 'xc(exported)');
    is($body->as_string, '<body/>', 'create an element');

    cmp_ok($body->as_string, 'eq', $body->toString, 'toString alias to as_string');
};

subtest 'basic creation' => sub {
    my $div = xc('div', class => 'pretty')
                ->c('h1')->t('hello')
                ->up
                ->c('p', class => 'intro')->t('world!')
                ->root;
    is($div->as_string, '<div class="pretty"><h1>hello</h1><p class="intro">world!</p></div>', '=head1 SYNOPSIS; block1 -> chained create elements');

    my $icon_el = xc('i', class => 'icon-download icon-white');
    is($icon_el->as_string, '<i class="icon-download icon-white"/>', '=head2 xc; sample');

    my $span_el = xc('span')->t('some')->t(' ')->t('more text');
    is($span_el->as_string, '<span>some more text</span>', '=haed2 t; sample');

    my $over_el = xc('overload');
    is("$over_el", '<overload/>', '=head2 as_string; sample');

    my $head2_root = xc('p')
        ->t('this ')
        ->c('b')
            ->t('is')->up
        ->t(' important!')
        ->root->as_string;
    is($head2_root, '<p>this <b>is</b> important!</p>', '=head2 root; sample');

    return;
};

done_testing;
