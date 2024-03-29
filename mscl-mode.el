;;; mscl-mode.el --- major mode for editing MSCL code -*- lexical-binding: t -*-

;; Copyright (C) 2020-2022 Eason Huang

;; Author: Eason Huang
;; Created: 2020-08-16
;; Version: 1.1.1
;; Keywords: mscl, languages
;; URL: https://github.com/Eason0210/mscl-mode
;; Package-Requires: ((seq "2.23") (emacs "29"))

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a major mode for editing MSCL code.  Features
;; include syntax highlighting and indentation.
;;
;; You can format the region, or the entire buffer, by typing C-c C-f.
;;

;; Installation:

;; To install manually, place mscl-mode.el in your load-path, and add
;; the following lines of code to your init file:
;;
;; (autoload 'mscl-mode "mscl-mode" "Major mode for editing MSCL code." t)
;; (add-to-list 'auto-mode-alist '("\\.pwx?macro\\'" . mscl-mode))

;; Configuration:

;; You can customize the indentation of code blocks, see variable
;; `mscl-indent-offset'.  The default value is 4.
;;
;; Formatting is also affected by the customizable variables
;; `mscl-delete-trailing-whitespace' and `delete-trailing-lines'
;; (from simple.el).
;;

;;; Code:

(require 'seq)

;; ----------------------------------------------------------------------------
;; Customization:
;; ----------------------------------------------------------------------------

(defgroup mscl nil
  "Major mode for editing MSCL code."
  :link '(emacs-library-link :tag "Source File" "mscl-mode.el")
  :group 'languages)

(defcustom mscl-mode-hook nil
  "*Hook run when entering MSCL mode."
  :type 'hook
  :group 'mscl)

(defcustom mscl-indent-offset 4
  "*Specifies the indentation offset for `mscl-indent-line'.
Statements inside a block are indented this number of columns."
  :type 'integer
  :group 'mscl)

(defcustom mscl-delete-trailing-whitespace nil
  "*Delete trailing whitespace while formatting code."
  :type 'boolean
  :group 'mscl)

;; ----------------------------------------------------------------------------
;; Variables:
;; ----------------------------------------------------------------------------

(defconst mscl-mode-version "1.1.1"
  "The current version of `mscl-mode'.")

(defconst mscl-increase-indent-keywords-bol
  (regexp-opt '("if" "elseif" "while")
              'symbols)
  "Regexp string of keywords that increase indentation.
These keywords increase indentation when found at the
beginning of a line.")

(defconst mscl-increase-indent-keywords-eol
  (regexp-opt '("else")
              'symbols)
  "Regexp string of keywords that increase indentation.
These keywords increase indentation when found at the
end of a line.")

(defconst mscl-decrease-indent-keywords-bol
  (regexp-opt '("else" "elseif" "endif" "endwhile")
              'symbols)
  "Regexp string of keywords that decrease indentation.
These keywords decrease indentation when found at the
beginning of a line or after a statement separator (:).")

(defconst mscl-backslash-keywords-eol
  (regexp-opt '("\\") 'sysbols)
  "Find backslash in the end of line.")

(defconst mscl-comment-and-string-faces
  '(font-lock-comment-face font-lock-comment-delimiter-face font-lock-string-face)
  "List of font-lock faces used for comments and strings.")

(defconst mscl-label-regexp
  "^[ \t]*\\([a-zA-Z][a-zA-Z0-9_.]*:\\)"
  "Regexp string of symbols to highlight as line numbers.")

(defconst mscl-constant-regexp
  (regexp-opt '("$_pwk_files_path"  "$_install_path" "$_temp_path"
                "$_userconfig_path" "$_app_nb_bit" "$_pi")
              'symbols)
  "Regexp string of symbols to highlight as constants.")

(defconst mscl-function-regexp
  (regexp-opt '("abs" "atan" "atan2" "asin" "acos" "cos" "size"
                "log10" "sin" "sqrt" "tan" "expr" "expr_i" "string_decimal" )
              'symbols)
  "Regexp string of symbols to highlight as functions.")

(defconst mscl-builtin-regexp
  (regexp-opt '("and" "not" "or")
              'symbols)
  "Regexp string of symbols to highlight as builtins.")

(defconst mscl-keyword-regexp
  (regexp-opt '("version" "set" "break" "continue" "declare"
                "else" "elseif"  "endif" "if" "while" "endwhile")
              'symbols)
  "Regexp string of symbols to highlight as keywords.")

(defconst mscl-type-regexp
  (regexp-opt '( "float")
              'symbols)
  "Regexp string of symbols to highlight as types.")

(defconst mscl-font-lock-keywords
  (list (list mscl-label-regexp 0 'font-lock-constant-face)
        (list mscl-constant-regexp 0 'font-lock-constant-face)
        (list mscl-keyword-regexp 0 'font-lock-keyword-face)
        (list mscl-type-regexp 0 'font-lock-type-face)
        (list mscl-function-regexp 0 'font-lock-function-name-face)
        (list mscl-builtin-regexp 0 'font-lock-builtin-face))
  "Describes how to syntax highlight keywords in `mscl-mode' buffers.")

;; ----------------------------------------------------------------------------
;; Indentation:
;; ----------------------------------------------------------------------------

(defun mscl-indent-line ()
  "Indent the current line of code, see function `mscl-calculate-indent'."
  (interactive)
  ;; If line needs indentation
  (when (not (mscl-code-indented-correctly-p))
    ;; Calculate new indentation
    (let* ((original-col (current-column))
           (original-indent-col (mscl-current-indent))
           (calculated-indent-col (mscl-calculate-indent)))
      ;; Indent line
      (indent-line-to calculated-indent-col)
      ;; Move point to a good place after indentation
      (goto-char (+ (pos-bol)
                    calculated-indent-col
                    (max (- original-col original-indent-col) 0))))))

(defun mscl-calculate-indent ()
  "Calculate the indent for the current line of code.
The current line is indented like the previous line, unless inside a block.
Code inside a block is indented `mscl-indent-offset' extra characters."
  (let ((previous-indent-col (mscl-previous-indent))
        (increase-indent (mscl-increase-indent-p))
        (decrease-indent (mscl-decrease-indent-p))
        (label (mscl-label-p)))
    (if label
        0
      (max 0 (+ previous-indent-col
                (if increase-indent mscl-indent-offset 0)
                (if decrease-indent (- mscl-indent-offset) 0))))))

(defun mscl-label-p ()
  "Return non-nil if current line does start with a label."
  (save-excursion
    (goto-char (line-beginning-position))
    (looking-at mscl-label-regexp)))


(defun mscl-backslash-p ()
  "Return non-nil if current line does end with a backslash."
  (save-excursion
    (goto-char (line-end-position))
    (looking-back mscl-backslash-keywords-eol nil)))

(defun mscl-backslash-backward-p ()
  "Search backward from point for a line end with a backslash."
  (save-excursion
    (beginning-of-line)
    (skip-chars-backward " \t\n")
    (looking-back mscl-backslash-keywords-eol nil)))


(defun mscl-comment-or-string-p ()
  "Return non-nil if point is in a comment or string."
  (let ((faces (get-text-property (point) 'face)))
    (unless (listp faces)
      (setq faces (list faces)))
    (seq-some (lambda (x) (memq x faces)) mscl-comment-and-string-faces)))

(defun mscl-code-search-backward ()
  "Search backward from point for a line containing code."
  (beginning-of-line)
  (skip-chars-backward " \t\n")
  (while (and (not (bobp)) (or (mscl-comment-or-string-p) (mscl-label-p)))
    (skip-chars-backward " \t\n")
    (when (not (bobp))
      (forward-char -1))))

(defun mscl-match-symbol-at-point-p (regexp)
  "Return non-nil if the symbol at point does match REGEXP."
  (let ((symbol (symbol-at-point))
        (case-fold-search t))
    (when symbol
      (string-match regexp (symbol-name symbol)))))

(defun mscl-increase-indent-p ()
  "Return non-nil if indentation should be increased.
Some keywords trigger indentation when found at the end of a line,
while other keywords do it when found at the beginning of a line."
  (save-excursion
    (mscl-code-search-backward)
    (unless (bobp)
      ;; Keywords at the end of the line
      (if (or (mscl-match-symbol-at-point-p mscl-increase-indent-keywords-eol)
              ;; when find "\" in the end of current line but not in previous line.
              (and (mscl-backslash-p)
                   (not (mscl-backslash-backward-p))))
          't
        ;; Keywords at the beginning of the line
        (beginning-of-line)
        (re-search-forward "[^0-9 \t\n]" (pos-eol) t)
        (mscl-match-symbol-at-point-p mscl-increase-indent-keywords-bol)))))

(defun mscl-decrease-indent-p ()
  "Return non-nil if indentation should be decreased.
Some keywords trigger un-indentation when found at the beginning
of a line or statement, see `mscl-decrease-indent-keywords-bol'."
  (save-excursion
    (beginning-of-line)
    (re-search-forward "[^0-9 \t\n]" (pos-eol) t)
    (or (mscl-match-symbol-at-point-p mscl-decrease-indent-keywords-bol)
        (let ((match nil))
          (mscl-code-search-backward)
          (beginning-of-line)
          (while (and (not match)
                      (re-search-forward ":[ \t\n]*" (pos-eol) t))
            (setq match (mscl-match-symbol-at-point-p mscl-decrease-indent-keywords-bol)))
          (or match
              ;; when find "\" in the end of previous line but not in current line.
              (and (mscl-backslash-backward-p)
                   (not (mscl-backslash-p))))))))

(defun mscl-current-indent ()
  "Return the indent column of the current code line."
  (save-excursion
    (beginning-of-line)
    ;; Skip spaces
    (skip-chars-forward " \t" (pos-eol))
    (let ((indent (- (point) (pos-bol))))
      indent)))

(defun mscl-previous-indent ()
  "Return the indent column of the previous code line.
If the current line is the first line, then return 0."
  (save-excursion
    (mscl-code-search-backward)
    (cond ((bobp) 0)
          (t (mscl-current-indent)))))

(defun mscl-code-indented-correctly-p ()
  "Return non-nil if code is indented correctly."
  (save-excursion
    (let ((original-indent-col (mscl-current-indent))
          (calculated-indent-col (mscl-calculate-indent)))
      (= original-indent-col calculated-indent-col))))

;; ----------------------------------------------------------------------------
;; Formatting:
;; ----------------------------------------------------------------------------

(defun mscl-delete-trailing-whitespace-line ()
  "Delete any trailing whitespace on the current line."
  (beginning-of-line)
  (when (re-search-forward "\\s-*$" (line-end-position) t)
    (replace-match "")))

(defun mscl-format-code ()
  "Format all lines in region, or entire buffer if region is not active.
Indent lines, and also remove any trailing whitespace if the
variable `mscl-delete-trailing-whitespace' is non-nil.

If this command acts on the entire buffer it also deletes all
trailing lines at the end of the buffer if the variable
`delete-trailing-lines' is non-nil."
  (interactive)
  (let* ((entire-buffer (not (use-region-p)))
         (point-start (if (use-region-p) (region-beginning) (point-min)))
         (point-end (if (use-region-p) (region-end) (point-max)))
         (line-end (line-number-at-pos point-end)))

    (save-excursion
      ;; Don't format last line if region ends on first column
      (goto-char point-end)
      (when (= (current-column) 0)
        (setq line-end (1- line-end)))

      ;; Loop over all lines and format
      (goto-char point-start)
      (while (and (<= (line-number-at-pos) line-end) (not (eobp)))
        (mscl-indent-line)
        (when mscl-delete-trailing-whitespace
          (mscl-delete-trailing-whitespace-line))
        (forward-line))

      ;; Delete trailing empty lines
      (when (and entire-buffer
                 delete-trailing-lines
                 (= (point-max) (1+ (buffer-size)))) ;; Really end of buffer?
        (goto-char (point-max))
        (backward-char)
        (while (eq (char-before) ?\n)
          (delete-char -1))
        ))))

;; ----------------------------------------------------------------------------
;; Xref backend:
;; ----------------------------------------------------------------------------

(declare-function xref-make "xref" (summary location))
(declare-function xref-make-buffer-location "xref" (buffer point))

(defun mscl-xref-backend () 'mscl)

(defun mscl-xref-make-xref (summary buffer point)
  "Return a buffer xref object with SUMMARY, BUFFER and POINT."
  (xref-make summary (xref-make-buffer-location buffer point)))

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql mscl)))
  (mscl-xref-identifier-at-point))

(defun mscl-xref-identifier-at-point ()
  "Return the relevant MSCL identifier at point."
  (let ((sym (thing-at-point 'symbol t)))
    (if (string= (substring sym 0 1) "$")
        (substring sym 1)
      sym)))

(cl-defmethod xref-backend-definitions ((_backend (eql mscl)) identifier)
  (mscl-xref-find-definitions identifier))

(defun mscl-xref-find-definitions (identifier)
  "Find definitions of IDENTIFIER.
Return a list of xref objects with the definitions found.
If no definitions can be found, return nil."
  (let (xrefs)
    (let ((label (mscl-xref-find-label identifier))
          (variables (mscl-xref-find-variable identifier)))
      (when label
        (push (mscl-xref-make-xref (format "%s (label)" identifier) (current-buffer) label) xrefs))
      (cl-loop for variable in variables do
               (push (mscl-xref-make-xref (format "%s (variable)" identifier) (current-buffer) variable) xrefs))
      xrefs)))

(defun mscl-xref-find-label (label)
  "Return the buffer position where LABEL is defined.
If LABEL is not found, return nil."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (concat "^\\s-*\\(" label "\\):") nil t)
      (match-beginning 1))))

(defun mscl-xref-find-variable (variable)
  "Return a list of buffer positions where VARIABLE is defined.
If VARIABLE is not found, return nil."
  (save-excursion
    (goto-char (point-min))
    (let (positions)
      (while (re-search-forward (concat "\\_<declare\\_>.*\\_<\\(" variable "\\)\\_>") nil t)
        (push (match-beginning 1) positions))
      positions)))

;; ----------------------------------------------------------------------------
;; MSCL mode:
;; ----------------------------------------------------------------------------

(defvar mscl-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-f" 'mscl-format-code)
    map)
  "Keymap used in ‘mscl-mode'.")

(defvar mscl-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_   "w   " table)
    (modify-syntax-entry ?\.  "w   " table)
    (modify-syntax-entry ?\\  "w   " table)
    (modify-syntax-entry ?#   "<   " table)
    (modify-syntax-entry ?\n  ">   " table)
    (modify-syntax-entry ?\^m ">   " table)
    table)
  "Syntax table used while in ‘mscl-mode'.")

;;;###autoload
(define-derived-mode mscl-mode prog-mode "MSCL"
  "Major mode for editing MSCL code.
Commands:
TAB indents for MSCL code.

\\{mscl-mode-map}"
  :group 'mscl
  (add-hook 'xref-backend-functions #'mscl-xref-backend nil t)
  (setq-local indent-line-function 'mscl-indent-line)
  (setq-local comment-start "#")
  (setq-local font-lock-defaults '(mscl-font-lock-keywords nil t))
  (unless font-lock-mode
    (font-lock-mode 1)))

;;;###autoload (add-to-list 'auto-mode-alist '("\\.pwx?macro\\'" . mscl-mode))

;; ----------------------------------------------------------------------------

(provide 'mscl-mode)

;;; mscl-mode.el ends here
