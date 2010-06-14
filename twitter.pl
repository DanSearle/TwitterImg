#! /usr/bin/perl

#+-----------------------------------------------------------------------------+
#|                                 Twitter.pl                                  |
#+-----------------------------------------------------------------------------+
#|    This is a script which takes a public twitter feed for a person and      |
#|    produces a simple image of the latest tweet with a profile image.        |
#|    In gif format.                                                           |
#+-----------------------------------------------------------------------------+
#|    This program is free software: you can redistribute it and/or modify     |
#|    it under the terms of the GNU General Public License as published by     |
#|    the Free Software Foundation, either version 3 of the License, or        |
#|    (at your option) any later version.                                      |
#|                                                                             |
#|    This program is distributed in the hope that it will be useful,          |
#|    but WITHOUT ANY WARRANTY; without even the implied warranty of           |
#|    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            |
#|    GNU General Public License for more details.                             |
#|                                                                             |
#|    You should have received a copy of the GNU General Public License        |
#|    along with this program.  If not, see <http://www.gnu.org/licenses/>.    |
#+-----------------------------------------------------------------------------+
#| Original Author: Dan Searle <code@d-searle.co.uk> (08-06-2010)              |
#+-----------------------------------------------------------------------------+

#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#|                             User Configuration                              |
#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#| Below is the options that control the script which the user can customise   |
#+-----------------------------------------------------------------------------+

# Twitter atom feed (grabbed from the source of your twitter profile page)
# Must be an atom feed in order to display the profile image
my $atomFeed = "**EDIT ME**";

# Place to cache the image file. Make sure the webserver user has read/write
# access to the destination directory.
my $cacheImg = "**EDIT ME**";

# Day difference to cache for
my $dateDelta = 1; # 1 Day

#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#|                                Program Code                                 |
#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+

# Librarys to use
use strict;
use CGI qw/:standard/;
use LWP::Simple;
use GD;
use File::stat;
use Date::Calc qw(Delta_DHMS);
use Date::Parse;

# Print the HTTP Headers
my $cgi = new CGI;
print $cgi->header( -expires => '+' . $dateDelta . 'd', -type => 'image/gif' ); 

# See if the cached file exists and how old it is
if ( -e $cacheImg ) {
  my $mtime = stat($cacheImg)->mtime;
  my($Dd, $Dh, $Dm, $Ds)  = timeDiff(localtime($mtime));
  if ($Dd >= $dateDelta) {
    # Generate a new image if the cache is old
    genImg();
  }
} else {
  # The cache file does not exist create it.
  genImg();
}

# Serve up the image file
showImg();


#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#|                      Time Difference Utility Routine                        |
#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#| Attribution to this code goes to ``Anonymous Monk'' and ``ikegami'' at the  |
#| perl monks website @ http://www.perlmonks.org/?node_id=76710                |
#+-----------------------------------------------------------------------------+
sub timeDiff(@) {
  my ($sec1, $min1, $hour1, $mday1, $month1, $year1,
    $dayofweek1, $dayofyear1, $isdst1) = localtime();
  my ($sec2, $min2, $hour2, $mday2, $month2, $year2,
    $dayofweek2, $dayofyear2, $isdst2) = @_;

  $month1 ++;
  $month2 ++;
  $year2 = $year2 + 1900;
  $year1 = $year1 + 1900;

  return Delta_DHMS($year2, $month2, $mday2, $hour2, $min2, $sec2,
    $year1, $month1, $mday1, $hour1, $min1, $sec1);
}

#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#|                       Trim whitespacing in a string                         |
#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#| Attribution to this code goes to ``japhy'' at the                           |
#| perl monks website @ http://www.perlmonks.org/?node_id=36684                |
#+-----------------------------------------------------------------------------+
sub trim {
  @_ = $_ if not @_ and defined wantarray;
  @_ = @_ if defined wantarray;
  for (@_ ? @_ : $_) { s/^\s+//, s/\s+$// }
  return wantarray ? @_ : $_[0] if defined wantarray;
}

#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#|                         Generate the Twitter Image                          |
#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#| Retrieve the feed and extract the important details, produce an image and   |
#| save it to the cache file.                                                  |
#+-----------------------------------------------------------------------------+
#| Original Author: Dan Searle <code@d-searle.co.uk> (08-06-2010)              |
#+-----------------------------------------------------------------------------+
sub genImg() {

  # Grab the twitter feed file
  my $content = get($atomFeed) or die $!;

  # Parse the content
  use XML::XPath;
  my $xp = XML::XPath->new( xml => $content );
  my $latestTweet = $xp->find('/feed/entry[1]/content');
  my $latestImage = $xp->find('/feed/entry[1]/link[@rel="image"]');
  my $latestTime  = $xp->find('/feed/entry[1]/published');
  my $tweet = "";
  my $image = "";
  my $time = "";

  # Get the first image
  foreach my $node ($latestImage->get_nodelist) {
    $image = XML::XPath::XMLParser::as_string($node);
  }

  # Get the first tweet
  foreach my $node ($latestTweet->get_nodelist) {
    $tweet = XML::XPath::XMLParser::as_string($node);
  }

  # Get the first time
  foreach my $node ($latestTime->get_nodelist) {
    $time = XML::XPath::XMLParser::as_string($node);
  }

  # Extract the profile image URL
  my $imageurl = "";
  if($image =~ /href="(.*?)"/) {
    $imageurl = $1;
  } 

  # Retrieve the profile image and convert it to a GD object
  my $profileimagecontent = get($imageurl) or die $!;
  my $profileimage = GD::Image->new($profileimagecontent); 

  # Extract the persons name and the tweets content.
  my $tweetperson  = "";
  my $tweetcontent = "";
  if($tweet =~ /<content.*?>(.*?):(.*)<\/content>/) {
    $tweetperson  = $1;
    $tweetcontent = $2;
  }

  # Extract the time
  my @tweettime;
  if($time =~ /<.*?>(.*?)<\/.*?>/) {
    @tweettime = localtime(str2time($1));
  }

  # Below is modified snippit from http://www.go4expert.com/forums/showthread.php?t=15533
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @tweettime;
  $year += 1900; 
  my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
  my @dayabbr = qw( 1st 2nd 3rd 4th 5th 6th 7th 8th 9th 10th 11th 12th 13th 14th 15th 16th 17th 18th 19th 20th 21st 22nd 23rd 24th 25th 26th 27th 28th 29th 30th 31st );
  my $timeformat = "$hour:$min $abbr[$mon] $dayabbr[$mday-1] $year";

  # Create a new image
  my $img = new GD::Image(400,54);

  # Image colours
  my $white = $img->colorAllocate(255,255,255);
  my $black = $img->colorAllocate(0,0,0);

  # Image background
  $img->filledRectangle(0,0,400,54,$white);

  # Add profile image
  $img->copy($profileimage,3,3,0,0,48,48);

  # Add bold text stating the persons name
  $img->string(gdMediumBoldFont, 54, 2, $tweetperson . ":", $black );

  # Add the tweet content to the image
  # First word wrap it
  if ( (length($tweetperson) + length($tweetcontent)*8) < 350 ) {
    $img->string(gdSmallFont, 54 + (length($tweetperson)*8), 3, $tweetcontent, $black );
  } else {
    my $linelen = 50 - length($tweetperson);

    #
    # Below snippit is attributed to ``poznick'' on the perl monks 
    # website @  http://www.perlmonks.org/?node_id=8383
    # 
    my $rest = $tweetcontent;
    my @text = ();
    while($rest ne '') {
      $rest =~ /(.{1,$linelen}\W)(.*)/ms;
      push @text, $1;
      $rest = $2;
    }

    # Add the split text to the image
    my $y = 3;
    foreach(@text) {
      $img->string(gdSmallFont, 54 + (length($tweetperson)*8), $y, trim($_), $black );
      $y += 10;
    }
  }

  # Save the gif image to the cache file
  open(IMG,">$cacheImg") or die $!;
  binmode IMG;
  print IMG $img->gif;
  close IMG;
}

#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#|                           Show the Twitter Image                            |
#+=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=+
#| Retrieve the cached image and send it to the output.                        |
#+-----------------------------------------------------------------------------+
#| Original Author: Dan Searle <code@d-searle.co.uk> (08-06-2010)              |
#+-----------------------------------------------------------------------------+
sub showImg() {
  open(IMG,"<$cacheImg") or die $!;
  binmode STDOUT;
  print <IMG>;
  close IMG;
}
