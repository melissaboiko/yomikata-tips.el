# yomikata-tips

This packages uses MECAB+Unidic to analyse Japanese text and
automatically infer kanji readings.  The readings are stored as Emacs
text properties and can be accessed by mouse hovering (tooltips) or
interactive commands.

## Installation

You need MECAB installed with the Unidic dictionary (alternative
dictionaries are planned but not yet supported).  On Debian you can
get them with:

   apt install mecab unidic-mecab

Note that unidic-mecab is several gigabytes in size.

## Usage

To analyse some text, run one of:
 - `yomikata-region`,
 - `yomikata-buffer`
 - or `yomikata-at-point`.
 
The readings will be stored as standard Emacs tooltips.¹  You can see
them by hovering the mouse pointer, or by calling `yomikata-at-point`
again at any word.

To remove the annotations, use
`yomikata-clear-tooltips-region` or
`yomikata-clear-tooltips-buffer`.

Annotated text is underlined by default.  To change this, customize
`yomikata-tooltip-available-face`.

1: Specifically they’re in the `'help-echo` text property, in a
package-specific text overlay.

## Disclaimer

Automatic morphological analysis and reading inference are imperfect
processes and may make errors.  This software is deterministic and the
errors are consistent and predictable.  The furigana generation is
100% offline, open source, and private.  No LLMs or so-called
“generative AI” are used at any point.  None of your data is sent
anywhere or used to train anything.  No coal plants had to be built to
train the datafiles used by this software.

## Bugs

This software currently doesn't understand Japanese words broken
between lines.  You might want to use soft line breaks for longer
text.

## Roadmap

 - Support more dictionary types than Unidic.
 - Modify text in-place to add HTML ruby tags or Markdown ruby.
   - Requires 
 - A minor mode with default keybindings
 - Option to show readings in minibuffer when “hovering” with the
   keyboard cursor (this can be done with help-at-pt-set-timer, but
   it's annoying because it flashes every time you advance a
   character.)
