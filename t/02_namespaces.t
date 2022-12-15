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

    is($body->first->single->as_xml_libxml->namespaceURI,$xhtml_xmlns,'body has default namespace');
    is($body->children->first->single->as_xml_libxml->namespaceURI,$xhtml_xmlns,'child has default namespace');
};

subtest 'element namespaces' => sub {
    my $sitemap = xc(\q{<?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
                xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
          <url>
            <loc>http://example.com/sample.html</loc>
            <image:image>
              <image:loc>http://example.com/image.jpg</image:loc>
            </image:image>
            <image:image>
              <image:loc>http://example.com/photo.jpg</image:loc>
            </image:image>
          </url>
        </urlset>
        <!-- https://support.google.com/webmasters/answer/178636?hl=en -->
    });
    $sitemap->reg_global_ns('i' => 'http://www.google.com/schemas/sitemap-image/1.1');
    is( $sitemap->find(
            '/s:urlset/z:url/i:image',
            's' => 'http://www.sitemaps.org/schemas/sitemap/0.9',
            'z' => 'http://www.sitemaps.org/schemas/sitemap/0.9',
            )->count,
        2,
        'two image:images elements'
    );
};

subtest 'create document with 2 namespaces' => sub {
    my $feed = xc(
        'feed',
        'xmlns'         => 'http://www.w3.org/2005/Atom',
        'xmlns:media' => 'http://search.yahoo.com/mrss/',
        'xml:lang'    => 'en-US'
    )->t("\n");
    my $item = $feed->c('entry')->t("\n");
    $item->a('id', '-' => 'http://blog.kutej.net/2022/12/')->t("\n");
    $item->a(
        'media:thumbnail',
        width  => '30',
        height => '30',
        url    => 'http://blog.kutej.net/static/img/bulk-discount.jpg'
    )->t("\n");

    eq_or_diff($feed->as_string, ns_document(), 'namespace elements');
};

done_testing;

sub ns_document {
    return
q{<feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/" xml:lang="en-US">
<entry>
<id>http://blog.kutej.net/2022/12/</id>
<media:thumbnail height="30" url="http://blog.kutej.net/static/img/bulk-discount.jpg" width="30"></media:thumbnail>
</entry></feed>};
}
