#!/usr/bin/perl
use XML::Simple;
use Data::Dumper;
 

my @dirlist = `/bin/ls /var/hmanager`;
foreach $dir (@dirlist )
{
$dir = "/var/hmanager/" . $dir; 
chomp($dir);
$cluster = (split(/\//,$dir))[3];
opendir (DIR, $dir) or die $!;
while (my $subdir = readdir(DIR)) {

next if ($subdir =~ m/^\./);
next unless (-d "$dir/$subdir");
my  @files = <$dir/$subdir/*>;

@arr=();
system("/bin/mkdir -p /var/www/$cluster/conf/$subdir");
$final_htm="/var/www/$cluster/conf/$subdir/" . $subdir."_conf.html";
system("cp /var/www/base_conf.html $final_htm");

foreach $file (@files)
{
$infile = (split(/\//,$file))[-1];


if($infile =~ /(.*)\./)
{
$out = "/var/www/$cluster/conf/$subdir/" . $1. ".html";
}

if($infile =~ /xml$/)
{
open(FOUT, ">$out") || die "Cant open $out";  
push @arr, $infile;
my $parser= XML::Simple->new();
 
my $doc = $parser->XMLin($file);
 
print FOUT qq(<html>
<head>
<link rel="stylesheet" type="text/css" href="/hm/assets/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/hm/assets/css/DT_bootstrap.css">
<script type="text/javascript" charset="utf-8" language="javascript" src="/hm/assets/js/jquery.js"></script>
<script type="text/javascript" charset="utf-8" language="javascript" src="/hm/assets/js/jquery.dataTables.js"></script>
<script type="text/javascript" charset="utf-8" language="javascript" src="/hm/assets/js/DT_bootstrap.js"></script>
</head>
<body>
<div class="container" style="margin-top: 30px">
<table cellpadding="0" cellspacing="0" border="0" class="table table-hover table-bordered" id="example">
<thead>
<tr>
<th><center>Property</th>
<th><center>Value</th>
</tr>
</thead>
<tbody>)
;
foreach my $key (keys (%{$doc->{property}})) {
#print "\n$doc->{property}->{$key} and doc->{property}->{$key}->{value}";
print FOUT "
 <tr>
<td>$key</td>
<td>$doc->{property}->{$key}->{value}</td>
</tr>
";
}
print FOUT "
</tbody>
</table>
</div>
</body>
</html>
";

}
elsif($infile =~ m/cfg$|conf$/)
{
push @arr, $infile;
if(-r $file )
{
open(F, "$file") || die "Cant open $file";  
open(FOUT, ">$out") || die "Cant open $out";  
$hash{$infile} = $out;
print FOUT "\n<pre>\n\n";
while(<F>)
{
print FOUT $_;
}
print FOUT "\n</pre>";
close F;
}
else
{
print "cant";
}

}
else
{
print "\nno action";
}
close FOUT;
}

open(FHTM, ">>$final_htm") || die "Cant open $final_htm";  

for $i ( 0 .. $#arr)
{
$j=$i+1;

if($i == 0 )
{
print FHTM "\n <li class=\"active\"><a href=\"#pane" . $j ."\" data-toggle=\"tab\">" . $arr[$i] . "</a></li>";
}
else
{
print FHTM "\n <li><a href=\"#pane" . $j ."\" data-toggle=\"tab\">" . $arr[$i] . "</a></li>";
}
}

print FHTM "\n</ul>";
print FHTM "\n<div class=\"tab-content\">" ;

for $i ( 0 .. $#arr)
{
$j=$i+1;
if($arr[$i] =~ /(.*)\./)
{
$out_file = $1. ".html";
}

if($i == 0 )
{
print FHTM "\n <div id=\"pane" . $j . "\" class=\"tab-pane active\">";
print FHTM "\n<iframe src=\"/$cluster/conf/" . $subdir . "/" . $out_file . "\" style=\"width: 100%; height: 100%; border: 0; overflow-x: scroll; overflow-y: scroll;\" ></iframe></div>" ;
}
else
{
print FHTM "\n <div id=\"pane" . $j . "\" class=\"tab-pane\">";
print FHTM "\n<iframe src=\"/$cluster/conf/" . $subdir . "/" . $out_file . "\" style=\"width: 100%; height: 100%; border: 0; overflow-x: scroll; overflow-y: scroll;\" ></iframe></div>" ;
}
}

my $today = `/bin/date`;
chomp($today);
print FHTM "\n </div></div><div class=\"footer\"> Gen at:" .  $today . " </div></body>";
print FHTM  "\n </html>";
close(FHTM);
}
closedir(DIR);

}
