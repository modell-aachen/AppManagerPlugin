# See bottom of file for default license and copyright information
package Foswiki::Plugins::AppManagerPlugin;

use strict;
use warnings;
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION 			= '0.1';
our $RELEASE 			= '0.1';
our $SHORTDESCRIPTION  	= 'AppManager';
our $NO_PREFS_IN_TOPIC 	= 1;

sub initPlugin {
	my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning('Version mismatch between ' . __PACKAGE__ . ' and Plugins.pm');
        return 0;
    }
	
    Foswiki::Func::registerTagHandler('AMPAPPLIST', \&_AMPAPPLIST);

	#bin/rest/AppManagerPlugin/example
    #Foswiki::Func::registerRESTHandler( 'example', \&restExample );

    return 1;
}

sub _AMPAPPLIST {
	my($session, $params, $topic, $web, $topicObject) = @_;
	
	print $session;
	
	if (!Foswiki::Func::isAnAdmin()) {
		return 'Not allowed to list installed applications.';
	}
	
	my $template 		= '<table><thead><tr></tr></thead><tbody>';
	my @topicList 		= Foswiki::Func::getTopicList('System');
	my @appContribs 	= ();
	my $i 				= 0;
	
	for($i ; $i < (scalar @topicList) ; $i++) {
		if (@topicList[$i] =~ /AppContrib$/) {
			push(@appContribs, @topicList[$i]);
			$template .= '<tr><td>' . @topicList[$i] . '</td></tr>';
		} 
	}
	
	$template .= '</tbody></table>';
	
	if (scalar @appContribs == 0) {
		return 0;
	}
	
	return $template;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
#sub _EXAMPLETAG {
#    my($session, $params, $topic, $web, $topicObject) = @_;
#    # $session  - a reference to the Foswiki session object
#    #             (you probably won't need it, but documented in Foswiki.pm)
#    # $params=  - a reference to a Foswiki::Attrs object containing
#    #             parameters.
#    #             This can be used as a simple hash that maps parameter names
#    #             to values, with _DEFAULT being the name for the default
#    #             (unnamed) parameter.
#    # $topic    - name of the topic in the query
#    # $web      - name of the web in the query
#    # $topicObject - a reference to a Foswiki::Meta object containing the
#    #             topic the macro is being rendered in (new for foswiki 1.1.x)
#    # Return: the result of processing the macro. This will replace the
#    # macro call in the final text.
#
#    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
#    # $params->{_DEFAULT} will be 'hamburger'
#    # $params->{sideorder} will be 'onions'
#}

=begin TML

---++ earlyInitPlugin()

This handler is called before any other handler, and before it has been
determined if the plugin is enabled or not. Use it with great care!

If it returns a non-null error string, the plugin will be disabled.

=cut

#sub earlyInitPlugin {
#    return undef;
#}

=begin TML

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username. Normally Foswiki gets the username
from the login manager. This handler gives you a chance to override the
login manager.

Return the *login* name.

This handler is called very early, immediately after =earlyInitPlugin=.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub initializeUserHandler {
#    my ( $loginName, $url, $pathInfo ) = @_;
#}

=begin TML

---++ finishPlugin()

Called when Foswiki is shutting down, this handler can be used by the plugin
to release resources - for example, shut down open database connections,
release allocated memory etc.

Note that it's important to break any cycles in memory allocated by plugins,
or that memory will be lost when Foswiki is run in a persistent context
e.g. mod_perl.

=cut

#sub finishPlugin {
#}

=begin TML

---++ registrationHandler($web, $wikiName, $loginName, $data )
   * =$web= - the name of the web in the current CGI query
   * =$wikiName= - users wiki name
   * =$loginName= - users login name
   * =$data= - a hashref containing all the formfields POSTed to the registration script

Called when a new user registers with this Foswiki.

Note that the handler is not called when the user submits the registration
form if {Register}{NeedVerification} is enabled. It is then called when
the user submits the activation code.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub registrationHandler {
#    my ( $web, $wikiName, $loginName, $data ) = @_;
#}

=begin TML

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is
     invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>MACROS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Only plugins that have to parse the entire topic content should implement
this function. For expanding macros with trivial syntax it is *far* more
efficient to use =Foswiki::Func::registerTagHandler= (see =initPlugin=).

Internal Foswiki macros, (and any macros declared using
=Foswiki::Func::registerTagHandler=) are expanded _before_, and then again
_after_, this function is called to ensure all %<nop>MACROS% are expanded.

*NOTE:* when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

*Since:* $Foswiki::Plugins::VERSION 2.0

=cut

#sub commonTagsHandler {
#    my ( $text, $topic, $web, $included, $meta ) = @_;
#
#    # If you don't want to be called from nested includes...
#    #   if( $included ) {
#    #         # bail out, handler called from an %INCLUDE{}%
#    #         return;
#    #   }
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called before Foswiki does any expansion of its own
internal variables. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

*NOTE*: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* This handler is not separately called on included topics.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

=cut

#sub beforeCommonTagsHandler {
#    my ( $text, $topic, $web, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called after Foswiki has completed expansion of %MACROS%.
It is designed for use by cache plugins. Note that when this handler
is called, &lt;verbatim> blocks are present in the text.

*NOTE*: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

=cut

#sub afterCommonTagsHandler {
#    my ( $text, $topic, $web, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced
     with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to
     the removed blocks.

Handler called immediately before Foswiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to
process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a
sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are
inserted into the text inside &lt;!--!marker!--&gt; characters so the
text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters
passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
</verbatim>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a
line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
        my $n = 1;
        $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e.
it may be called several times during the rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

Since Foswiki::Plugins::VERSION = '2.0'

=cut

#sub preRenderingHandler {
#    my( $text, $pMap ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

*NOTE*: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

Since Foswiki::Plugins::VERSION = '2.0'

=cut

#sub postRenderingHandler {
#    my $text = shift;
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. It is called once when the =edit= script is run.

*NOTE*: meta-data may be embedded in the text passed to this handler 
(using %META: tags)

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub beforeEditHandler {
#    my ( $text, $topic, $web ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterEditHandler($text, $topic, $web, $meta )
   * =$text= - text that is being previewed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data for the topic.
This handler is called by the preview script just before presenting the text.
It is called once when the =preview= script is run.

*NOTE:* this handler is _not_ called unless the text is previewed.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $Foswiki::Plugins::VERSION 2.0

=cut

#sub afterEditHandler {
#    my ( $text, $topic, $web ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a Foswiki::Meta object.

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

*Since:* Foswiki::Plugins::VERSION = 2.0

=cut

#sub beforeSaveHandler {
#    my ( $text, $topic, $web ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a Foswiki::Meta object 

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in $text (using %META: tags)

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub afterSaveHandler {
#    my ( $text, $topic, $web, $error, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterRenameHandler( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment )

   * =$oldWeb= - name of old web
   * =$oldTopic= - name of old topic (empty string if web rename)
   * =$oldAttachment= - name of old attachment (empty string if web or topic rename)
   * =$newWeb= - name of new web
   * =$newTopic= - name of new topic (empty string if web rename)
   * =$newAttachment= - name of new attachment (empty string if web or topic rename)

This handler is called just after the rename/move/delete action of a web, topic or attachment.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub afterRenameHandler {
#    my ( $oldWeb, $oldTopic, $oldAttachment,
#         $newWeb, $newTopic, $newAttachment ) = @_;
#}

=begin TML

---++ beforeUploadHandler(\%attrHash, $meta )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$meta= - the Foswiki::Meta object where the upload will happen

This handler is called once when an attachment is uploaded. When this
handler is called, the attachment has *not* been recorded in the database.

The attributes hash will include at least the following attributes:
   * =attachment= => the attachment name - must not be modified
   * =user= - the user id - must not be modified
   * =comment= - the comment - may be modified
   * =stream= - an input stream that will deliver the data for the
     attachment. The stream can be assumed to be seekable, and the file
     pointer will be positioned at the start. It is *not* necessary to
     reset the file pointer to the start of the stream after you are
     done, nor is it necessary to close the stream.

The handler may wish to replace the original data served by the stream
with new data. In this case, the handler can set the ={stream}= to a
new stream.

For example:
<verbatim>
sub beforeUploadHandler {
    my ( $attrs, $meta ) = @_;
    my $fh = $attrs->{stream};
    local $/;
    # read the whole stream
    my $text = <$fh>;
    # Modify the content
    $text =~ s/investment bank/den of thieves/gi;
    $fh = new File::Temp();
    print $fh $text;
    $attrs->{stream} = $fh;

}
</verbatim>

*Since:* Foswiki::Plugins::VERSION = 2.1

=cut

#sub beforeUploadHandler {
#    my( $attrHashRef, $topic, $web ) = @_;
#}

=begin TML

---++ afterUploadHandler(\%attrHash, $meta )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$meta= - a Foswiki::Meta  object where the upload has happened

This handler is called just after the after the attachment
meta-data in the topic has been saved. The attributes hash
will include at least the following attributes, all of which are read-only:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id

*Since:* Foswiki::Plugins::VERSION = 2.1

=cut

#sub afterUploadHandler {
#    my( $attrHashRef, $meta ) = @_;
#}

=begin TML

---++ mergeHandler( $diff, $old, $new, \%info ) -> $text
Try to resolve a difference encountered during merge. The =differences= 
array is an array of hash references, where each hash contains the 
following fields:
   * =$diff= => one of the characters '+', '-', 'c' or ' '.
      * '+' - =new= contains text inserted in the new version
      * '-' - =old= contains text deleted from the old version
      * 'c' - =old= contains text from the old version, and =new= text
        from the version being saved
      * ' ' - =new= contains text common to both versions, or the change
        only involved whitespace
   * =$old= => text from version currently saved
   * =$new= => text from version being saved
   * =\%info= is a reference to the form field description { name, title,
     type, size, value, tooltip, attributes, referenced }. It must _not_
     be wrtten to. This parameter will be undef when merging the body
     text of the topic.

Plugins should try to resolve differences and return the merged text. 
For example, a radio button field where we have 
={ diff=>'c', old=>'Leafy', new=>'Barky' }= might be resolved as 
='Treelike'=. If the plugin cannot resolve a difference it should return 
undef.

The merge handler will be called several times during a save; once for 
each difference that needs resolution.

If any merges are left unresolved after all plugins have been given a 
chance to intercede, the following algorithm is used to decide how to 
merge the data:
   1 =new= is taken for all =radio=, =checkbox= and =select= fields to 
     resolve 'c' conflicts
   1 '+' and '-' text is always included in the the body text and text
     fields
   1 =&lt;del>conflict&lt;/del> &lt;ins>markers&lt;/ins>= are used to 
     mark 'c' merges in text fields

The merge handler is called whenever a topic is saved, and a merge is 
required to resolve concurrent edits on a topic.

*Since:* Foswiki::Plugins::VERSION = 2.0

=cut

#sub mergeHandler {
#    my ( $diff, $old, $new, $info ) = @_;
#}

=begin TML

---++ modifyHeaderHandler( \%headers, $query )
   * =\%headers= - reference to a hash of existing header values
   * =$query= - reference to CGI query object
Lets the plugin modify the HTTP headers that will be emitted when a
page is written to the browser. \%headers= will contain the headers
proposed by the core, plus any modifications made by other plugins that also
implement this method that come earlier in the plugins list.
<verbatim>
$headers->{expires} = '+1h';
</verbatim>

Note that this is the HTTP header which is _not_ the same as the HTML
&lt;HEAD&gt; tag. The contents of the &lt;HEAD&gt; tag may be manipulated
using the =Foswiki::Func::addToHEAD= method.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub modifyHeaderHandler {
#    my ( $headers, $query ) = @_;
#}

=begin TML

---++ renderFormFieldForEditHandler($name, $type, $size, $value, $attributes, $possibleValues) -> $html

This handler is called before built-in types are considered. It generates 
the HTML text rendering this form field, or false, if the rendering 
should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field (checkbox, radio etc)
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if
     any. May be a scalar (one legal value) or a ref to an array
     (several legal values)

Return HTML text that renders this field. If false, form rendering
continues by considering the built-in types.

*Since:* Foswiki::Plugins::VERSION 2.0

Note that you can also extend the range of available
types by providing a subclass of =Foswiki::Form::FieldDefinition= to implement
the new type (see =Foswiki::Extensions.JSCalendarContrib= and
=Foswiki::Extensions.RatingContrib= for examples). This is the preferred way to
extend the form field types.

=cut

#sub renderFormFieldForEditHandler {
#    my ( $name, $type, $size, $value, $attributes, $possibleValues) = @_;
#}

=begin TML

---++ renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
   * =$linkText= - the text for the link i.e. for =[<nop>[Link][blah blah]]=
     it's =blah blah=, for =BlahBlah= it's =BlahBlah=, and for [[Blah Blah]] it's =Blah Blah=.
   * =$hasExplicitLinkLabel= - true if the link is of the form =[<nop>[Link][blah blah]]= (false if it's ==<nop>[Blah]] or =BlahBlah=)
   * =$web=, =$topic= - specify the link being rendered

Called during rendering, this handler allows the plugin a chance to change
the rendering of labels used for links.

Return the new link text.

NOTE: this handler is to allow a plugin to change the link text for a possible link - it may never be used.
for example, Set ALLOWTOPICVIEW = is a possible ACRONYM link that will not be displayed unless the topic exists
similarly, this handler is called before the Plurals code has a chance to remove the 's' from WikiWords

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub renderWikiWordHandler {
#    my( $linkText, $hasExplicitLinkLabel, $web, $topic ) = @_;
#    return $linkText;
#}

=begin TML

---++ completePageHandler($html, $httpHeaders)

This handler is called on the ingredients of every page that is
output by the standard CGI scripts. It is designed primarily for use by
cache and security plugins.
   * =$html= - the body of the page (normally &lt;html>..$lt;/html>)
   * =$httpHeaders= - the HTTP headers. Note that the headers do not contain
     a =Content-length=. That will be computed and added immediately before
     the page is actually written. This is a string, which must end in \n\n.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub completePageHandler {
#    my( $html, $httpHeaders ) = @_;
#    # modify $_[0] or $_[1] if you must change the HTML or headers
#    # You can work on $html and $httpHeaders in place by using the
#    # special perl variables $_[0] and $_[1]. These allow you to operate
#    # on parameters as if they were passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via the query object in the $session, for example:

my $query = $session->{request};
my $web = $query->{param}->{web}[0];

If your rest handler adds or replaces equivalent functionality to a standard script
provided with Foswiki, it should set the appropriate context in its switchboard entry.
In addition to the obvous contexts:  =view=, =diff=,  etc. the =static= context is used
to indicate that the resulting output will be read offline, such as in a PDF,  and 
dynamic links (edit, sorting, etc) should not be rendered.

A comprehensive list of core context identifiers used by Foswiki is found in
%SYSTEMWEB%.IfStatements#Context_identifiers. Please be careful not to
overwrite any of these identifiers!

For more information, check %SYSTEMWEB%.CommandAndCGIScripts#rest

For information about handling error returns from REST handlers, see
Foswiki:Support.Faq1

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub restExample {
#   my ( $session, $subject, $verb, $response ) = @_;
#   return "This is an example of a REST invocation\n\n";
#}

=begin TML

---++ Deprecated handlers

---+++ redirectCgiQueryHandler($query, $url )
   * =$query= - the CGI query
   * =$url= - the URL to redirect to

This handler can be used to replace Foswiki's internal redirect function.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

*Deprecated in:* Foswiki::Plugins::VERSION 2.1

This handler was deprecated because it cannot be guaranteed to work, and
caused a significant impediment to code improvements in the core.

---+++ beforeAttachmentSaveHandler(\%attrHash, $topic, $web )

   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called once when an attachment is uploaded. When this
handler is called, the attachment has *not* been recorded in the database.

The attributes hash will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id
   * =tmpFilename= - name of a temporary file containing the attachment data

*Deprecated in:* Foswiki::Plugins::VERSION 2.1

The efficiency of this handler (and therefore it's impact on performance)
is very bad. Please use =beforeUploadHandler()= instead.

=begin TML

---+++ afterAttachmentSaveHandler(\%attrHash, $topic, $web )

   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string generated during the save process (always
     undef in 2.1)

This handler is called just after the save action. The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id

*Deprecated in:* Foswiki::Plugins::VERSION 2.1

This handler has a number of problems including security and performance
issues. Please use =afterUploadHandler()= instead.

=cut

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: %$AUTHOR%

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.