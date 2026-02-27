;;; yomikata.el --- Annotates Japanese text with reading tooltips -*- lexical-binding: t; -*-

;; Copyleft 🄯 2026 Melissa Boiko

;; Author: Melissa Boiko
;; Keywords: i18n mouse text
;; Package-Version: 0.1
;; Package-Requires: ((emacs "29.1"))
;; URL: https://example.com
;; License: AGPL 3

;;; Commentary:

;; This packages uses MECAB-Unidic to automatically generate readings
;; for kanji in an Emacs buffer.
;;
;; To annotate the text, run `yomikata-region', `yomikata-buffer', or
;; `yomikata-at-point'.  The readings will be saved as help-echo text
;; properties.  To see them, hover the mouse pointer, or by call
;; `yomikata-at-point' again at any word.
;;
;; You need MECAB installed with the Unidic dictionary (alternative
;; dictionaries are planned but not yet supported).  On Debian you can
;; get them with:
;;
;;    apt install mecab unidic-mecab
;;
;; Note that unidic-mecab is several gigabytes in size.
;;
;; The annotations are saved in package-specific overlays.  To clear
;; them, use `yomikata-clear-tooltips-region' or
;; `yomikata-clear-tooltips-buffer'.
;;
;; Annotated text is underlined by default.  To change this, customize
;; `yomikata-tooltip-available-face'.
;;
;;
;; Automatic morphological analysis and reading inference are
;; imperfect processes and may make errors.  This software is
;; deterministic, and its errors are consistent and predictable.  The
;; inference is 100% offline, open source, and private.  No LLMs or
;; so-called “generative AI” are used at any point.  None of your
;; data is sent anywhere or used to train anything.  No coal plants
;; had to be built to train datafiles used by this software.
;;
;; This software currently doesn't understand Japanese words broken
;; between lines.  You might want to use soft line breaks for longer
;; text.


;;; Code:

(require 'cl-lib)
(defcustom yomikata-mecab-command
  "/usr/bin/mecab"
  "Path to mecab executable."
  :type '(file :must-match t)
  :group 'yomikata)

(defcustom yomikata-mecab-arguments
  '("-d" "/var/lib/mecab/dic/unidic/")
  "List of arguments to pass to mecab."
  :type '(repeat string)
  :group 'yomikata)

(defface yomikata-tooltip-available-face
  '((t . (:underline (:color "orange" :style dots :position 1))))
  "Face to hint that a word has a kana reading tooltip."
  :group 'yomikata)

(defconst yomikata--kata-to-hira
  '(
    (?ァ . ?ぁ)
    (?ア . ?あ)
    (?ィ . ?ぃ)
    (?イ . ?い)
    (?ゥ . ?ぅ)
    (?ウ . ?う)
    (?ェ . ?ぇ)
    (?エ . ?え)
    (?ォ . ?ぉ)
    (?オ . ?お)
    (?カ . ?か)
    (?ガ . ?が)
    (?キ . ?き)
    (?ギ . ?ぎ)
    (?ク . ?く)
    (?グ . ?ぐ)
    (?ケ . ?け)
    (?ゲ . ?げ)
    (?コ . ?こ)
    (?ゴ . ?ご)
    (?サ . ?さ)
    (?ザ . ?ざ)
    (?シ . ?し)
    (?ジ . ?じ)
    (?ス . ?す)
    (?ズ . ?ず)
    (?セ . ?せ)
    (?ゼ . ?ぜ)
    (?ソ . ?そ)
    (?ゾ . ?ぞ)
    (?タ . ?た)
    (?ダ . ?だ)
    (?チ . ?ち)
    (?ヂ . ?ぢ)
    (?ッ . ?っ)
    (?ツ . ?つ)
    (?ヅ . ?づ)
    (?テ . ?て)
    (?デ . ?で)
    (?ト . ?と)
    (?ド . ?ど)
    (?ナ . ?な)
    (?ニ . ?に)
    (?ヌ . ?ぬ)
    (?ネ . ?ね)
    (?ノ . ?の)
    (?ハ . ?は)
    (?バ . ?ば)
    (?パ . ?ぱ)
    (?ヒ . ?ひ)
    (?ビ . ?び)
    (?ピ . ?ぴ)
    (?フ . ?ふ)
    (?ブ . ?ぶ)
    (?プ . ?ぷ)
    (?ヘ . ?へ)
    (?ベ . ?べ)
    (?ペ . ?ぺ)
    (?ホ . ?ほ)
    (?ボ . ?ぼ)
    (?ポ . ?ぽ)
    (?マ . ?ま)
    (?ミ . ?み)
    (?ム . ?む)
    (?メ . ?め)
    (?モ . ?も)
    (?ャ . ?ゃ)
    (?ヤ . ?や)
    (?ュ . ?ゅ)
    (?ユ . ?ゆ)
    (?ョ . ?ょ)
    (?ヨ . ?よ)
    (?ラ . ?ら)
    (?リ . ?り)
    (?ル . ?る)
    (?レ . ?れ)
    (?ロ . ?ろ)
    (?ヮ . ?ゎ)
    (?ワ . ?わ)
    (?ヰ . ?ゐ)
    (?ヱ . ?ゑ)
    (?ヲ . ?を)
    (?ン . ?ん)
    (?ヴ . ?ヴ)
    ;; (?ヷ . "わ゙")
    ;; (?ヸ . :ゐ゙")
    ;; (?ヹ . "ゑ゙")
    ;; (?ヺ . "を゙")
    ))

(defun yomikata--hiraganize (katakana-string)
  "Convert katakana in KATAKANA-STRING to hiragana.

Does not handle exotic katakana such as phonetic annotations, etc. Used
internally only with the kana reading field of MECAB-Unidic."

  (mapconcat (lambda (c)
               (let ((hira (alist-get c yomikata--kata-to-hira)))
                 (if hira
                     (char-to-string hira)
                   (char-to-string c))))
             katakana-string ""))

(defun yomikata--kanji-p (char)
  "True if CHAR is Han script."
  (eq (aref char-script-table char) 'han))

(defun yomikata--has-kanji-p (string)
  "True if STRING has at least one kanji character."
  (seq-some 'yomikata--kanji-p string))

(defun yomikata--mecab-parse-unidic-line (line)
  "Extract surface and kana-token fields from MECAB-Unidic output LINE.

Returned pair as (surface . kana-token).

If the line doesn't seem to have the fields, return nil.  This will
happen with the EOS line at the end of the Mecab output."

  (let* ((basefields (split-string line "\t"))
         (surface (car basefields)))
    (if (> (length basefields) 1)
        (let* ((morpho-fields (split-string (cadr basefields) ","))
               (reading (nth 20 morpho-fields)))
          (cons surface reading))
      nil)))

(defun yomikata--mecab-from-string (str)
  "Call mecab with STR as input.  Return list of lines."
  (with-temp-buffer
    (apply #'call-process-region
           str nil
           yomikata-mecab-command
           nil ; don't delete
           t   ; output in buffer
           nil ; don't redisplay
           yomikata-mecab-arguments)
    (split-string (buffer-string) "\n" t)))

(defun yomikata-map-mecab-region-readings (start end func)
  "Tokenize region, then call FUNC on each token while passing the reading.

Region is pased as START and END positions.
FUNC will be called with arguments: (token-start token-end reading)."

  (let* ((text (buffer-substring-no-properties start end))
         (mecab-output (yomikata--mecab-from-string text)))
    (save-excursion
      (goto-char start)
      (dolist (line mecab-output)
        (let ((fields (yomikata--mecab-parse-unidic-line line)))
          (when fields
            (let ((surface (car  fields))
                  (reading (cdr fields)))

              (search-forward surface end t)
              (when (and (not (string-equal surface reading))
                         (yomikata--has-kanji-p surface))
                (let ((hiragana-reading (yomikata--hiraganize reading)))
                  (when (not (string-equal surface hiragana-reading))
                    (let ((token-start (match-beginning 0))
                          (token-end (match-end 0)))
                      (funcall func token-start token-end hiragana-reading))))))))))))

;; We use overlays because pure put-text-property 'help-echo is
;; fragile with font lock of various modes.
(defun yomikata--add-tooltip (start end tooltip)
  "Add overlay with kanji reading TOOLTIP through region (START END)."
  (let ((ov (make-overlay start end)))
    (overlay-put ov 'help-echo tooltip)
    (overlay-put ov 'face 'yomikata-tooltip-available-face)
    (overlay-put ov 'yomikata 'mecab-reading)))

(defun yomikata-clear-tooltips-region (start end)
  "Clear any kanji tooltips in region (START END)."
  (interactive "r")
  (remove-overlays start end 'yomikata 'mecab-reading))

(defun yomikata-clear-tooltips-buffer nil
  "Clear all kanji tooltips in buffer."
  (interactive)
  (yomikata-clear-tooltips-region (point-min) (point-max)))

(defun yomikata-region (start end)
  "Run MECAB on region (START END) and annotate it with kanji readings."
  (interactive "r")
  (yomikata-map-mecab-region-readings start end
                             (lambda (token-start token-end reading)
                               (yomikata--add-tooltip token-start token-end reading))))

(defun yomikata-buffer nil
  "Annotate entire buffer for kanji reading tooltips."
  (interactive)
  (yomikata-region (point-min) (point-max)))

(defun yomikata--find-overlay-at (pos)
  "Return kanji reading overlay at POS if it was already set, otherwise nil."
  (cl-find-if (lambda (ov) (overlay-get ov 'yomikata))
              (overlays-at pos)))

(defun yomikata--get-reading-at-point nil
  "Return previously annotated reading at point, if any."
  (let ((overlay (yomikata--find-overlay-at (point))))
    (when overlay
      (overlay-get overlay 'help-echo))))

(defun yomikata-at-point nil
  "Run analysis on current line if needed, then return kanji reading at point."
  (interactive)
  (let ((previous-overlay (yomikata--find-overlay-at (point))))
    (if previous-overlay
        (message (overlay-get previous-overlay 'help-echo))
      (save-excursion
        (yomikata-region (pos-bol) (pos-eol))
        (message (yomikata--get-reading-at-point))))))

(provide 'yomikata)

;;; yomikata.el ends here
