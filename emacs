(add-to-list 'load-path "~/.emacs.d/")
(add-to-list 'load-path "~/.emacs.d/auto-install/")


;; Make emacs a little prettier
;; ----------------------------

(setq inhibit-startup-screen t)

; The colour theme package isn't needed. I'll keep this in
; the comments for a few commits anyhow though.
;
; (add-to-list 'load-path "/Users/joekarma/.emacs.d/color-theme-6.6.0")
;
; (require 'color-theme)
; (eval-after-load "color-theme"
; '(progn
;   (color-theme-initialize)))

(load "tomorrow-night-theme.el")

;; ...and more readable
(set-face-attribute 'default nil :height 140)

;; ...and bigger, bolder
(defun set-frame-size-according-to-resolution ()
  (interactive)
  (if window-system
  (progn
    ;; use 120 char wide window for largeish displays
    ;; and smaller 80 column windows for smaller displays
    ;; pick whatever numbers make sense for you
    (if (> (x-display-pixel-width) 1280)
           (add-to-list 'default-frame-alist (cons 'width 130))
           (add-to-list 'default-frame-alist (cons 'width 80)))
    ;; for the height, subtract a couple hundred pixels
    ;; from the screen height (for panels, menubars and
    ;; whatnot), then divide by the height of a char to
    ;; get the height we want
    (add-to-list 'default-frame-alist 
         (cons 'height (/ (- (x-display-pixel-height) 100)
                             (frame-char-height)))))))

(set-frame-size-according-to-resolution)





;; Make emacs easier to use
;; ------------------------

(global-set-key "\C-c\C-a" 'mark-whole-buffer)
(add-to-list 'load-path "~/.emacs.d/helm")
(require 'helm-config)
(global-set-key (kbd "C-c C-SPC") 'helm-mini)




;; Make copy paste work right
;; --------------------------

(defun copy-from-osx ()
  (shell-command-to-string "pbpaste"))

(defun paste-to-osx (text &optional push)
  (let ((process-connection-type nil))
    (let ((proc (start-process "pbcopy" "*Messages*" "pbcopy")))
      (process-send-string proc text)
      (process-send-eof proc))))

(setq interprogram-cut-function 'paste-to-osx)
(setq interprogram-paste-function 'copy-from-osx)





;; Paredit and other Lisp editing helpers
;; --------------------------------------

(add-to-list 'load-path "~/.emacs.d/paredit")

(autoload 'paredit-mode "paredit"
  "Minor mode for pseudo structurally editing Lisp code." t)
(add-hook 'emacs-lisp-mode-hook       (lambda () (paredit-mode +1)))
(add-hook 'lisp-mode-hook             (lambda () (paredit-mode +1)))
(add-hook 'lisp-interaction-mode-hook (lambda () (paredit-mode +1)))
(add-hook 'scheme-mode-hook           (lambda () (paredit-mode +1)))
(add-hook 'lisp-mode-hook             (lambda () (paredit-mode +1)))

;; Stop SLIME's REPL from grabbing DEL,
;; which is annoying when backspacing over a '('
(defun override-slime-repl-bindings-with-paredit ()
  (define-key slime-repl-mode-map
    (read-kbd-macro paredit-backward-delete-key) nil))

(add-hook 'slime-repl-mode-hook 'override-slime-repl-bindings-with-paredit)
(add-hook 'slime-repl-mode-hook (lambda () (paredit-mode +1)))

(defvar electrify-return-match
  "[\]}\)\"]"
  "If this regexp matches the text after the cursor, do an \"electric\"
  return.")
  (defun electrify-return-if-match (arg)
    "If the text after the cursor matches `electrify-return-match' then
  open and indent an empty line between the cursor and the text.  Move the
  cursor to the new line."
    (interactive "P")
    (let ((case-fold-search nil))
      (if (looking-at electrify-return-match)
	    (save-excursion (newline-and-indent)))
      (newline arg)
      (indent-according-to-mode)))

;; Using local-set-key in a mode-hook is a better idea.
(global-set-key (kbd "RET") 'electrify-return-if-match)

;; Slime
(load (expand-file-name "~/quicklisp/slime-helper.el"))

;; Replace "sbcl" with the path to your implementation
(setq inferior-lisp-program "/opt/local/bin/ccl64")

(global-set-key (kbd "C-c g") 'slime-selector)
(set (make-local-variable lisp-indent-function)
     'common-lisp-indent-function)

;;; get emacs to understand what a reader macro looks like
;;; http://lists.common-lisp.net/pipermail/slime-devel/2010-August/017686.html
;;; --------------------------------------------------------------------------

(defun aak:add-lisp-reader-macros-syntactic-keyword ()
  "Register # numarg macro-character as a font lock syntactic
keyword, turning it into expression prefix."
  (set (make-local-variable 'parse-sexp-lookup-properties) t)
  (set (make-local-variable 'font-lock-syntactic-keywords)
       '(("\\(\\W\\|$\\)\\#\\([0-9]*[A-Za-z?]\\)" (2 "'")))))

(add-hook 'lisp-mode-hook 'aak:add-lisp-reader-macros-syntactic-keyword)

(defadvice add-text-properties
  (before aak:slime-propertize-with-font-lock-face activate)
  (when (eq 'slime-repl-mode major-mode)
    (let* ((props (ad-get-arg 2))
	   (face (getf props 'face)))
      (when face
	(push face props)
	(push 'font-lock-face props)
	(when (memq 'face (getf props 'rear-nonsticky))
	  (push 'font-lock-face (getf props 'rear-nonsticky)))
	(ad-set-arg 2 props)))))

(defun aak:enable-font-lock-for-slime-repl ()
  "Enable font lock mode in slime REPL buffer."
  (font-lock-fontify-buffer) ;; don't know why it's needed..
  (font-lock-mode 1))

(add-hook 'slime-repl-mode-hook
          'aak:add-lisp-reader-macros-syntactic-keyword)
(add-hook 'slime-repl-mode-hook
	  'aak:enable-font-lock-for-slime-repl)

;;; stop paredit from inserting an extra space after #p, #+, etc.
;;; http://paste.lisp.org/display/111419
;;; -------------------------------------------------------------

(defvar paredit-space-for-delimiter-predicates nil)

(defun paredit-space-for-delimiter-p (endp delimiter)
  ;; If at the buffer limit, don't insert a space.  If there is a word,
  ;; symbol, other quote, or non-matching parenthesis delimiter (i.e. a
  ;; close when want an open the string or an open when we want to
  ;; close the string), do insert a space.
  (and (not (if endp (eobp) (bobp)))
       (memq (char-syntax (if endp (char-after) (char-before)))
             (list ?w ?_ ?\"
                   (let ((matching (matching-paren delimiter)))
                     (and matching (char-syntax matching)))
                   (and (not endp)
                        (eq ?\" (char-syntax delimiter))
                        ?\) )))
       (catch 'exit
         (dolist (predicate paredit-space-for-delimiter-predicates)
           (if (not (funcall predicate endp delimiter))
               (throw 'exit nil)))
         t)))

(defvar common-lisp-octothorpe-quotation-characters '(?P))
(defvar common-lisp-octothorpe-parameter-parenthesis-characters '(?A))
(defvar common-lisp-octothorpe-parenthesis-characters '(?+ ?- ?C))

(defun paredit-space-for-delimiter-predicate-common-lisp (endp delimiter)
  (or endp
      (let ((case-fold-search t)
            (look
             (lambda (prefix characters n)
               (looking-back
                (concat prefix (regexp-opt (mapcar 'string characters)))
                (- (point) n)))))
        (let ((oq common-lisp-octothorpe-quotation-characters)
              (op common-lisp-octothorpe-parenthesis-characters)
              (opp common-lisp-octothorpe-parameter-parenthesis-characters))
          (cond ((eq (char-syntax delimiter) ?\()
                 (and (not (funcall look "#" op 2))
                      (not (funcall look "#[0-9]*" opp 20))))
                ((eq (char-syntax delimiter) ?\")
                 (not (funcall look "#" oq 2)))
                (else t))))))

(add-hook 'lisp-mode-hook
          (defun common-lisp-mode-hook-paredit ()
            (make-local-variable 'paredit-space-for-delimiter-predicates)
            (add-to-list 'paredit-space-for-delimiter-predicates
                         'paredit-space-for-delimiter-predicate-common-lisp)))







;; JavaScript
;; ----------

(autoload 'espresso-mode "espresso.el")
(autoload 'js2-mode "js2-20090723b.elc" nil t)
(add-to-list 'auto-mode-alist '("\\.js" . js2-mode))

(defun my-indent-sexp ()
  (interactive)
  (save-restriction
    (save-excursion
      (widen)
      (let* ((inhibit-point-motion-hooks t)
             (parse-status (syntax-ppss (point)))
             (beg (nth 1 parse-status))
             (end-marker (make-marker))
             (end (progn (goto-char beg) (forward-list) (point)))
             (ovl (make-overlay beg end)))
        (set-marker end-marker end)
        (overlay-put ovl 'face 'highlight)
        (goto-char beg)
        (while (< (point) (marker-position end-marker))
          ;; don't reindent blank lines so we don't set the "buffer
          ;; modified" property for nothing
          (beginning-of-line)
          (unless (looking-at "\\s-*$")
            (indent-according-to-mode))
          (forward-line))
        (run-with-timer 0.5 nil '(lambda(ovl)
                                   (delete-overlay ovl)) ovl)))))


(defun my-js2-indent-function ()
  (interactive)
  (save-restriction
    (widen)
    (let* ((inhibit-point-motion-hooks t)
           (parse-status (save-excursion (syntax-ppss (point-at-bol))))
           (offset (- (current-column) (current-indentation)))
           (indentation (espresso--proper-indentation parse-status))
           node)

      (save-excursion

        ;; I like to indent case and labels to half of the tab width
        (back-to-indentation)
        (if (looking-at "case\\s-")
            (setq indentation (+ indentation (/ espresso-indent-level 2))))

        ;; consecutive declarations in a var statement are nice if
        ;; properly aligned, i.e:
        ;;
        ;; var foo = "bar",
        ;;     bar = "foo";
        (setq node (js2-node-at-point))
        (when (and node
                   (= js2-NAME (js2-node-type node))
                   (= js2-VAR (js2-node-type (js2-node-parent node))))
          (setq indentation (+ 4 indentation))))

      (indent-line-to indentation)
      (when (> offset 0) (forward-char offset)))))


(defun my-js2-mode-hook ()
  (require 'espresso)
  (setq espresso-indent-level 4
        indent-tabs-mode nil
        c-basic-offset 4)
  (c-toggle-auto-state 0)
  (c-toggle-hungry-state 1)
  (set (make-local-variable 'indent-line-function) 'my-js2-indent-function)
  (define-key js2-mode-map [(meta control |)] 'cperl-lineup)
  (define-key js2-mode-map [(meta control \;)] 
    '(lambda()
       (interactive)
       (insert "/* -----[ ")
       (save-excursion
         (insert " ]----- */"))
       ))
  (define-key js2-mode-map [(return)] 'newline-and-indent)
  (define-key js2-mode-map [(backspace)] 'c-electric-backspace)
  (define-key js2-mode-map [(control d)] 'c-electric-delete-forward)
  (define-key js2-mode-map [(control meta q)] 'my-indent-sexp)
  (if (featurep 'js2-highlight-vars)
    (js2-highlight-vars-mode))
  (message "My JS2 hook"))

(add-hook 'js2-mode-hook 'my-js2-mode-hook)





;; Some Mac GUI Stuff
;; ------------------

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )



;; Start emacs in projects directory
;; ---------------------------------

(find-file "~/projects/")
