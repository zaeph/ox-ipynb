;;; ox-ipynb.el --- Org-mode exporter for Jupyter notebooks  -*- fill-column: 78; lexical-binding: t; -*-

;; Copyright © 2020 Leo Vivier <zaeph@zaeph.net>

;; Author: Leo Vivier <zaeph@zaeph.net>
;; URL: https://github.com/zaeph/ox-ipynb
;; Keywords: org, jupyter
;; Version: 0.1.0
;; Package-Requires: org

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; This package provides an org-mode exporter for Jupyter notebooks.

;;; Code:

;;; Dependencies

(require 'cl-lib)
(require 'ox-html)
(require 'ox-publish)


;;; User-Configurable Variables

(defgroup org-export-ipynb nil
  "Options specific to Jupyter export back-end."
  :tag "Org Jupyter"
  :group 'org-export
  :version "24.4"
  :package-version '(Org . "8.0"))


;;; Define Back-End

(org-export-define-derived-backend 'ipynb 'html
  :menu-entry
  '(?j "Export to Jupyter"
       ((?J "To temporary buffer"
	    (lambda (a s v b) (org-ipynb-export-as-ipynb a s v)))
	(?j "To file" (lambda (a s v b) (org-ipynb-export-to-ipynb a s v)))
	(?o "To file and open"
	    (lambda (a s v b)
	      (if a (org-ipynb-export-to-ipynb t s v)
		(org-open-file (org-ipynb-export-to-ipynb nil s v)))))))
  :translate-alist '((bold . org-md-bold)
		     (code . org-md-verbatim)
                     (example-block . org-ipynb-example-block)
		     (export-block . org-ipynb-export-block)
		     (fixed-width . org-ipynb-example-block)
		     (headline . org-ipynb-headline)
		     (horizontal-rule . org-ipynb-horizontal-rule)
		     (inline-src-block . org-ipynb-verbatim)
		     (inner-template . org-ipynb-inner-template)
                     (italic . org-md-italic)
		     (item . org-md-item)
		     (keyword . org-ipynb-keyword)
                     (latex-fragment . org-html-latex-fragment)
		     (line-break . org-ipynb-line-break)
		     (link . org-html-link)
		     (node-property . org-ipynb-node-property)
		     (paragraph . org-ipynb-paragraph)
                     (plain-list . org-ipynb-plain-list)
                     (plain-text . org-ipynb-plain-text)
		     (property-drawer . org-ipynb-property-drawer)
		     (quote-block . org-ipynb-quote-block)
                     (section . org-md-section)
		     (src-block . org-ipynb-example-block)
		     (template . org-ipynb-template)
                     (verbatim . org-md-verbatim))
  :options-alist
  '((:ipynb-options "IPYNB_OPTIONS" nil nil t)
    (:md-footnote-format nil nil org-md-footnote-format)
    (:md-footnotes-section nil nil org-md-footnotes-section)
    (:md-headline-style nil nil org-md-headline-style)))


;;; Filters


;;; Transcode Functions

;;;; Helper functions

(defvar org-ipynb--cells-staging nil
  "Variable to hold the stack of cells to export.")

(defun org-ipynb--format-markdown-cell (contents)
  "Format CONTENTS as a JSON block."
  (let ((print-escape-newlines t)
        (print-circle t))
    (prin1-to-string
     `((cell_type . markdown)
       (metadata . ,(make-hash-table))
       (source . ,(vconcat (list contents)))))))

(defun org-ipynb--format-code-cell (contents)
  "Format CONTENTS as a JSON block."
  (let ((print-escape-newlines t)
        (print-circle t))
    (prin1-to-string
     `((cell_type . code)
       (metadata . ,(make-hash-table))
       (execution_count . 1)
       (source . ,(vconcat (list contents)))
       (outputs . ,(vconcat (list '((name . stdout)
                                    (output_type . stream)
                                    (text . "foo")))))))))

;;;; Example Block, Src Block and Export Block

(defun org-ipynb-example-block (example-block _contents info)
  "Transcode EXAMPLE-BLOCK element into Markdown format.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (org-ipynb--format-code-cell
   (substring (org-export-format-code-default example-block info)
              0 -1)))

(defun org-ipynb-export-block (export-block contents info)
  "Transcode a EXPORT-BLOCK element from Org to Markdown.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (if (member (org-element-property :type export-block) '("MARKDOWN" "MD"))
      (org-remove-indentation (org-element-property :value export-block))
    ;; Also include HTML export blocks.
    (org-export-with-backend 'html export-block contents info)))

;;;; Headline

(defun org-ipynb-headline (headline contents info)
  "Transcode HEADLINE element into Markdown format.
CONTENTS is the headline contents.  INFO is a plist used as
a communication channel."
  (unless (org-element-property :footnote-section-p headline)
    (let* ((level (org-export-get-relative-level headline info))
           (title (org-export-data (org-element-property :title headline) info))
           (todo (and (plist-get info :with-todo-keywords)
                      (let ((todo (org-element-property :todo-keyword
                                    headline)))
                        (and todo (concat (org-export-data todo info) " ")))))
           (tags (and (plist-get info :with-tags)
                      (let ((tag-list (org-export-get-tags headline info)))
                        (and tag-list
                             (concat "     " (org-make-tag-string tag-list))))))
           (priority
            (and (plist-get info :with-priority)
                 (let ((char (org-element-property :priority headline)))
                   (and char (format "[#%c] " char)))))
           ;; Headline text without tags.
           (heading (concat todo priority title))
           (style (plist-get info :md-headline-style)))
      (cond
       ;; Cannot create a headline.  Fall-back to a list.
       ((or (org-export-low-level-p headline info)
            (not (memq style '(atx setext)))
            (and (eq style 'atx) (> level 6))
            (and (eq style 'setext) (> level 2)))
        (let ((bullet
               (if (not (org-export-numbered-headline-p headline info)) "-"
                 (concat (number-to-string
                          (car (last (org-export-get-headline-number
                                      headline info))))
                         "."))))
          (concat bullet (make-string (- 4 (length bullet)) ?\s) heading tags "\n\n"
                  (and contents (replace-regexp-in-string "^" "    " contents)))))
       (t
        (let ((anchor
               (and (org-md--headline-referred-p headline info)
                    (format "<a id=\"%s\"></a>"
                            (or (org-element-property :CUSTOM_ID headline)
                                (org-export-get-reference headline info))))))
          (concat (org-ipynb--format-markdown-cell (org-md--headline-title style level heading anchor tags))
                  contents)))))))

(defun org-ipynb--headline-referred-p (headline info)
  "Non-nil when HEADLINE is being referred to.
INFO is a plist used as a communication channel.  Links and table
of contents can refer to headlines."
  (unless (org-element-property :footnote-section-p headline)
    (or
     ;; Global table of contents includes HEADLINE.
     (and (plist-get info :with-toc)
	  (memq headline
		(org-export-collect-headlines info (plist-get info :with-toc))))
     ;; A local table of contents includes HEADLINE.
     (cl-some
      (lambda (h)
	(let ((section (car (org-element-contents h))))
	  (and
	   (eq 'section (org-element-type section))
	   (org-element-map section 'keyword
	     (lambda (keyword)
	       (when (equal "TOC" (org-element-property :key keyword))
		 (let ((case-fold-search t)
		       (value (org-element-property :value keyword)))
		   (and (string-match-p "\\<headlines\\>" value)
			(let ((n (and
				  (string-match "\\<[0-9]+\\>" value)
				  (string-to-number (match-string 0 value))))
			      (local? (string-match-p "\\<local\\>" value)))
			  (memq headline
				(org-export-collect-headlines
				 info n (and local? keyword))))))))
	     info t))))
      (org-element-lineage headline))
     ;; A link refers internally to HEADLINE.
     (org-element-map (plist-get info :parse-tree) 'link
       (lambda (link)
	 (eq headline
	     (pcase (org-element-property :type link)
	       ((or "custom-id" "id") (org-export-resolve-id-link link info))
	       ("fuzzy" (org-export-resolve-fuzzy-link link info))
	       (_ nil))))
       info t))))

(defun org-ipynb--headline-title (style level title &optional anchor tags)
  "Generate a headline title in the preferred Markdown headline style.
STYLE is the preferred style (`atx' or `setext').  LEVEL is the
header level.  TITLE is the headline title.  ANCHOR is the HTML
anchor tag for the section as a string.  TAGS are the tags set on
the section."
  (let ((anchor-lines (and anchor (concat anchor "\n\n"))))
    ;; Use "Setext" style
    (if (and (eq style 'setext) (< level 3))
        (let* ((underline-char (if (= level 1) ?= ?-))
               (underline (concat (make-string (length title) underline-char)
                                  "\n")))
          (concat "\n" anchor-lines title tags "\n" underline "\n"))
      ;; Use "Atx" style
      (let ((level-mark (make-string level ?#)))
        (concat anchor-lines level-mark " " title tags)))))

;;;; Horizontal Rule

(defun org-ipynb-horizontal-rule (_horizontal-rule _contents _info)
  "Transcode HORIZONTAL-RULE element into Markdown format.
CONTENTS is the horizontal rule contents.  INFO is a plist used
as a communication channel."
  "---")

;;;; Keyword

(defun org-ipynb-keyword (keyword contents info)
  "Transcode a KEYWORD element into Markdown format.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (pcase (org-element-property :key keyword)
    ((or "MARKDOWN" "MD") (org-element-property :value keyword))
    ("TOC"
     (let ((case-fold-search t)
	   (value (org-element-property :value keyword)))
       (cond
	((string-match-p "\\<headlines\\>" value)
	 (let ((depth (and (string-match "\\<[0-9]+\\>" value)
			   (string-to-number (match-string 0 value))))
	       (scope
		(cond
		 ((string-match ":target +\\(\".+?\"\\|\\S-+\\)" value) ;link
		  (org-export-resolve-link
		   (org-strip-quotes (match-string 1 value)) info))
		 ((string-match-p "\\<local\\>" value) keyword)))) ;local
	   (org-remove-indentation
	    (org-ipynb--build-toc info depth keyword scope)))))))
    (_ (org-export-with-backend 'html keyword contents info))))

;;;; Line Break

(defun org-ipynb-line-break (_line-break _contents _info)
  "Transcode LINE-BREAK object into Markdown format.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  "  \n")

;;;; Node Property

(defun org-ipynb-node-property (node-property _contents _info)
  "Transcode a NODE-PROPERTY element into Markdown syntax.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (format "%s:%s"
          (org-element-property :key node-property)
          (let ((value (org-element-property :value node-property)))
            (if value (concat " " value) ""))))

;;;; Paragraph

(defun org-ipynb--combine-object (object contents info)
  "Merge OBJECT’s CONTENTS with INFO."
  (let* ((contents (org-md-paragraph object contents info))
         (next (org-export-get-next-element object info))
         (next-type (car next))
         (staging org-ipynb--cells-staging)
         (concat-types '(paragraph plain-list quote-block)))
    (cond ((and (member next-type concat-types)
                (< (org-element-property :post-blank object) 2))
           (setq org-ipynb--cells-staging (concat staging contents "\n"))
           nil)
          (t
           (let ((contents (concat staging contents)))
             (setq org-ipynb--cells-staging nil)
             (org-ipynb--format-markdown-cell contents))))))

(defun org-ipynb-paragraph (paragraph contents info)
  "Transcode PARAGRAPH element into Markdown format.
CONTENTS is the paragraph contents.  INFO is a plist used as
a communication channel."
  (let* ((parent (org-export-get-parent paragraph))
         (parent-type (car parent))
         (no-cell-types '(quote-block item)))
    (if (member parent-type no-cell-types)
        contents
      (org-ipynb--combine-object paragraph contents info))))

;;;; Plain List

(defun org-ipynb-plain-list (plain-list contents info)
  "Transcode PLAIN-LIST element into Markdown format.
CONTENTS is the plain-list contents.  INFO is a plist used as
a communication channel."
  (let* ((parent (org-export-get-parent plain-list))
         (parent-type (car parent))
         (no-cell-types '(item)))
    (if (member parent-type no-cell-types)
        contents
      (org-ipynb--combine-object plain-list contents info))))

;;;; Plain Text

(defun org-ipynb-plain-text (text info)
  "Transcode a TEXT string into Markdown format.
TEXT is the string to transcode.  INFO is a plist holding
contextual information."
  (when (plist-get info :with-smart-quotes)
    (setq text (org-export-activate-smart-quotes text :utf-8 info)))
  ;; The below series of replacements in `text' is order sensitive.
  ;; Protect `, *, _, and \
  (setq text (replace-regexp-in-string "[`*_\\]" "\\\\\\&" text))
  ;; Protect ambiguous #.  This will protect # at the beginning of
  ;; a line, but not at the beginning of a paragraph.  See
  ;; `org-md-paragraph'.
  (setq text (replace-regexp-in-string "\n#" "\n\\\\#" text))
  ;; Protect ambiguous !
  (setq text (replace-regexp-in-string "\\(!\\)\\[" "\\\\!" text nil nil 1))
  ;; Handle special strings, if required.
  (when (plist-get info :with-special-strings)
    (setq text (org-html-convert-special-strings text)))
  ;; Handle break preservation, if required.
  (when (plist-get info :preserve-breaks)
    (setq text (replace-regexp-in-string "[ \t]*\n" "  \n" text)))
  ;; Return value.
  text)

;;;; Property Drawer

(defun org-ipynb-property-drawer (_property-drawer contents _info)
  "Transcode a PROPERTY-DRAWER element into Markdown format.
CONTENTS holds the contents of the drawer.  INFO is a plist
holding contextual information."
  (and (org-string-nw-p contents)
       (replace-regexp-in-string "^" "    " contents)))

;;;; Quote Block

(defun org-ipynb-quote-block (quote-block contents info)
  "Transcode QUOTE-BLOCK element into Markdown format.
CONTENTS is the quote-block contents.  INFO is a plist used as
a communication channel."
  (let* ((contents (format "%s\n" contents))
         (contents (replace-regexp-in-string "^" "> " contents)))
    (org-ipynb--combine-object quote-block contents info)))

;;;; Section

(defun org-ipynb-section (_section contents _info)
  "Transcode SECTION element into Markdown format.
CONTENTS is the section contents.  INFO is a plist used as
a communication channel."
  contents)

;;;; Template

(defun org-ipynb--build-toc (info &optional n _keyword scope)
  "Return a table of contents.

INFO is a plist used as a communication channel.

Optional argument N, when non-nil, is an integer specifying the
depth of the table.

When optional argument SCOPE is non-nil, build a table of
contents according to the specified element."
  (concat
   (unless scope
     (let ((style (plist-get info :md-headline-style))
	   (title (org-html--translate "Table of Contents" info)))
       (org-ipynb--headline-title style 1 title nil)))
   (mapconcat
    (lambda (headline)
      (let* ((indentation
	      (make-string
	       (* 4 (1- (org-export-get-relative-level headline info)))
	       ?\s))
	     (bullet
	      (if (not (org-export-numbered-headline-p headline info)) "-   "
		(let ((prefix
		       (format "%d." (org-last (org-export-get-headline-number
						headline info)))))
		  (concat prefix (make-string (max 1 (- 4 (length prefix)))
					      ?\s)))))
	     (title
	      (format "[%s](#%s)"
		      (org-export-data-with-backend
		       (org-export-get-alt-title headline info)
		       (org-export-toc-entry-backend 'md)
		       info)
		      (or (org-element-property :CUSTOM_ID headline)
			  (org-export-get-reference headline info))))
	     (tags (and (plist-get info :with-tags)
			(not (eq 'not-in-toc (plist-get info :with-tags)))
			(org-make-tag-string
			 (org-export-get-tags headline info)))))
	(concat indentation bullet title tags)))
    (org-export-collect-headlines info n scope) "\n")
   "\n"))

(defun org-ipynb--footnote-formatted (footnote info)
  "Formats a single footnote entry FOOTNOTE.
FOOTNOTE is a cons cell of the form (number . definition).
INFO is a plist with contextual information."
  (let* ((fn-num (car footnote))
         (fn-text (cdr footnote))
         (fn-format (plist-get info :md-footnote-format))
         (fn-anchor (format "fn.%d" fn-num))
         (fn-href (format " href=\"#fnr.%d\"" fn-num))
         (fn-link-to-ref (org-html--anchor fn-anchor fn-num fn-href info)))
    (concat (format fn-format fn-link-to-ref) " " fn-text "\n")))

(defun org-ipynb--footnote-section (info)
  "Format the footnote section.
INFO is a plist used as a communication channel."
  (let* ((fn-alist (org-export-collect-footnote-definitions info))
         (fn-alist (cl-loop for (n _type raw) in fn-alist collect
                            (cons n (org-trim (org-export-data raw info)))))
         (headline-style (plist-get info :md-headline-style))
         (section-title (org-html--translate "Footnotes" info)))
    (when fn-alist
      (format (plist-get info :md-footnotes-section)
              (org-ipynb--headline-title headline-style 1 section-title)
              (mapconcat (lambda (fn) (org-ipynb--footnote-formatted fn info))
                         fn-alist
                         "\n")))))

(defun org-ipynb-inner-template (contents info)
  "Return body of document after converting it to Markdown syntax.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  ;; Make sure CONTENTS is separated from table of contents and
  ;; footnotes with at least a blank line.
  (concat
   ;; Table of contents.
   (let* ((depth (plist-get info :with-toc)))
     (when depth
       (let ((toc (org-html-toc depth info)))
         (org-ipynb--format-markdown-cell toc))))
   ;; Document contents.
   contents
   "\n"
   ;; Footnotes section.
   (org-ipynb--footnote-section info)))

(defun org-ipynb--plist-to-alist (plist)
  "Convert PLIST to an alist."
  (when plist
    (cons
     (cons (keyword-to-symbol (car plist))
           (let ((cadr (cadr plist)))
             (if (json-plist-p cadr)
                 (plist->alist cadr)
               cadr)))
     (plist->alist (cddr plist)))))

(defun org-ipynb--parse-options (info)
  "Parse the options provided with `#+ipynb_options'.
INFO is a plist used as a communication channel"
  (let ((options (read (format "(%s)" (plist-get info :ipynb-options)))))
    (plist->alist options)))

(defun org-ipynb-template (contents info)
  "Return complete document string after Markdown conversion.
CONTENTS is the transcoded contents string.  INFO is a plist used
as a communication channel."
  (let ((options (org-ipynb--parse-options info))
        (cells (read (format "(%s)" contents))))
    (with-temp-buffer
      (insert
       (json-encode
        `((cells . ,(vconcat cells))
          (metadata (kernelspec (display_name . "Python 3")
                                (language . "python")
                                (name . "python3"))
                    (language_info (codemirror_mode . ((name . ipython)
                                                       (version . 3)))
                                   (file_extension . ".py")
                                   (mimetype . "text/x-python")
                                   (name . "python")
                                   (nbconvert_exporter . "python")
                                   (pygments_lexer . "ipython3")
                                   (version . "3.5.2"))
                    ,@options)
          (nbformat . 4)
          (nbformat_minor . 0))))
      (json-pretty-print (point-min) (point-max))
      (buffer-string))))



;;; Interactive function

;;;###autoload
(defun org-ipynb-export-as-ipynb (&optional async subtreep visible-only)
  "Export current buffer to a Markdown buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Export is done in a buffer named \"*Org MD Export*\", which will
be displayed when `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (setq org-ipynb--cells-staging nil)
  (org-export-to-buffer 'ipynb "*Org Jupyter Export*"
    async subtreep visible-only nil nil (lambda () (text-mode))))

;;;###autoload
(defun org-ipynb-convert-region-to-md ()
  "Assume the current region has Org syntax, and convert it to Markdown.
This can be used in any buffer.  For example, you can write an
itemized list in Org syntax in a Markdown buffer and use
this command to convert it."
  (interactive)
  (org-export-replace-region-by 'md))


;;;###autoload
(defun org-ipynb-export-to-ipynb (&optional async subtreep visible-only)
  "Export current buffer to a Markdown file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Return output file's name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".ipynb" subtreep)))
    (org-export-to-file 'ipynb outfile async subtreep visible-only)))

;;;###autoload
(defun org-ipynb-publish-to-md (plist filename pub-dir)
  "Publish an org file to Markdown.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

Return output file name."
  (org-publish-org-to 'md filename ".md" plist pub-dir))

(provide 'ox-ipynb)

;; Local variables:
;; generated-autoload-file: "org-loaddefs.el"
;; End:

;;; ox-ipynb.el ends here
