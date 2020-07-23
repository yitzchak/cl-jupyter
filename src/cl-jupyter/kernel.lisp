(in-package #:common-lisp-jupyter)

(defvar +display-name+ "Common Lisp")
(defvar +language+ "common-lisp")
(defvar +eval-flag+
  #+clisp "-x" #+(or mkcl cmucl) "-eval" #-(or clisp cmucl mkcl) "--eval")
(defvar +load-flag+
  #+clisp "-i" #+(or mkcl cmucl) "-load" #-(or clisp cmucl mkcl) "--load")

(defclass kernel (jupyter:kernel)
  ()
  (:default-initargs
    :name "common-lisp"
    :package (find-package :common-lisp-user)
    :version "0.1"
    :banner "common-lisp-jupyter: a Common Lisp Jupyter kernel
(C) 2019-2020 Tarn Burton (MIT)"
    :language-name "common-lisp"
    :language-version (uiop:lisp-version-string)
    :mime-type "text/x-common-lisp"
    :file-extension ".lisp"
    :pygments-lexer "common-lisp"
    :codemirror-mode "text/x-common-lisp"
    :help-links '(("Common Lisp Documentation" . "https://common-lisp.net/documentation")
                  ("Common Lisp HyperSpec" . "http://www.lispworks.com/documentation/HyperSpec/Front/index.htm"))))

(defmethod jupyter:code-is-complete ((k kernel) code)
  (handler-case
    (iter
      (for sexpr in-stream (make-string-input-stream code)))
    (end-of-file () "incomplete")
    (serious-condition () "invalid")
    (condition () "invalid")
    (:no-error (val)
      (declare (ignore val))
      "complete")))

(defun my-read (&optional input-stream (eof-error-p t) eof-value recursive-p)
  (jupyter:handling-errors
    (read input-stream eof-error-p eof-value recursive-p)))

(defun my-eval (expr)
  (jupyter:debugging-errors
  (setq common-lisp-user::- expr)
  (let ((evaluated-expr (multiple-value-list (eval expr))))
    (setq common-lisp-user::*** common-lisp-user::**
          common-lisp-user::** common-lisp-user::*
          common-lisp-user::* (car evaluated-expr)
          common-lisp-user::/// common-lisp-user:://
          common-lisp-user::// common-lisp-user::/
          common-lisp-user::/ evaluated-expr
          common-lisp-user::+++ common-lisp-user::++
          common-lisp-user::++ common-lisp-user::+
          common-lisp-user::+ expr)
    (remove nil (mapcar #'jupyter:make-lisp-result evaluated-expr)))))

(defmethod jupyter:evaluate-code ((k kernel) code)
  (iter
    (for sexpr in-stream (make-string-input-stream code) using #'my-read)
    (when (typep sexpr 'jupyter:result)
      (collect sexpr)
      (finish))
    (for result next (my-eval sexpr))
    (if (listp result)
      (appending result)
      (collect result))
    (until (jupyter:quit-eval-error-p result))))

(defun symbol-char-p (c)
  (and (characterp c)
       (or (alphanumericp c)
           (member c '(#\+ #\- #\< #\> #\/ #\* #\& #\= #\. #\? #\_ #\! #\$ #\%
                       #\: #\@ #\[ #\] #\^ #\{ #\} #\~ #\# #\|)))))

(defun symbol-string-at-position (value pos)
  (let ((start-pos (if (symbol-char-p (char value pos)) pos (if (zerop pos) 0 (1- pos)))))
    (if (symbol-char-p (char value start-pos))
      (let ((start (1+ (or (position-if-not #'symbol-char-p value :end start-pos :from-end t) -1)))
            (end (or (position-if-not #'symbol-char-p value :start start-pos) (length value))))
        (values (subseq value start end) start end))
      (values nil nil nil))))

(defclass inspect-result (jupyter:result)
  ((symbol :initarg :symbol
           :reader inspect-result-symbol)
   (status :initarg :status
           :reader inspect-result-status)))

(defmethod jupyter:render ((res inspect-result))
  (jupyter:json-new-obj
    ("text/plain"
      (with-output-to-string (stream)
        (describe (inspect-result-symbol res) stream)))))

(defun normalize-symbol-case (name)
  (case (readtable-case *readtable*)
    (:upcase (string-upcase name))
    (:downcase (string-downcase name))
    (:invert
      (cond
        ((every #'upper-case-p name) (string-downcase name))
        ((every #'lower-case-p name) (string-upcase name))
        (t name)))
    (otherwise name)))

(defun mangle-symbol-case (name)
  (case (readtable-case *readtable*)
    (:upcase (string-downcase name))
    (:downcase (string-upcase name))
    (:invert
      (cond
        ((every #'upper-case-p name) (string-downcase name))
        ((every #'lower-case-p name) (string-upcase name))
        (t name)))
    (otherwise name)))

(defun package-char-p (ch)
  (equal #\: ch))

(defun split-qualified-name (name)
  (let* ((normalized-name (normalize-symbol-case name))
         (pos (position-if #'package-char-p normalized-name))
         (start (if pos
                  (or (position-if-not #'package-char-p normalized-name :start pos)
                      (length name))
                  0)))
    (values
      (subseq normalized-name start)
      (cond
        ((equal pos 0) "KEYWORD")
        (pos (subseq normalized-name 0 pos)))
      (and pos (= 1 (- start pos))))))

(defun find-qualified-symbol (name default-package)
  (multiple-value-bind (name package)
                       (split-qualified-name name)
    (if (or (not name) (zerop (length name)))
      (values nil nil)
      (find-symbol name (or package default-package)))))

(defmethod jupyter:inspect-code ((k kernel) code cursor-pos detail-level)
  (jupyter:handling-errors
    (with-slots (package) k
      (multiple-value-bind (sym status)
                           (find-qualified-symbol
                             (values (symbol-string-at-position code cursor-pos))
                             package)
        (when sym
          (make-instance 'inspect-result
            :symbol sym
            :status status))))))

(defun symbol-name-to-qualified-name (name package-name package)
  (mangle-symbol-case
    (if package-name
      (multiple-value-bind (sym status) (find-symbol name package)
        (declare (ignore sym))
        (format nil "~A~A~A"
          (if (equal package-name "KEYWORD") "" package-name)
          (if (equal status :external) ":" "::")
          name))
      name)))

(defun remove-if-not-match (partial-name matches)
  (remove-if-not (lambda (match)
                   (starts-with-subseq partial-name match))
                 matches))


(defgeneric complete-fragment (frag type)
  (:method (frag type)
    (declare (ignore frag type))))


(defun complete-symbol (partial-name package statuses)
  (when package
    (let (matches)
      (do-symbols (sym package matches)
        (let ((sym-name (symbol-name sym)))
          (multiple-value-bind (s status)
                               (find-symbol sym-name package)
            (declare (ignore s))
            (when (and (member status statuses :test #'eql)
                       (starts-with-subseq partial-name sym-name))
              (push sym-name matches))))))))


(defun complete-package (partial-name &key include-marker)
  (let ((matches (remove-if-not-match
                   partial-name
                   (append (mapcan (lambda (pkg)
                                     (cons (package-name pkg)
                                           (package-nicknames pkg)))
                                   (list-all-packages))
                           #+(or abcl clasp ecl) (mapcar #'car (ext:package-local-nicknames *package*))
                           #+allegro (mapcar #'car (excl:package-local-nicknames *package*))
                           #+ccl (mapcar #'car (ccl:package-local-nicknames *package*))
                           #+lispworks (mapcar #'car (hcl:package-local-nicknames *package*))
                           #+sbcl (mapcar #'car (sb-ext:package-local-nicknames *package*))))))
    (if include-marker
      (mapcar (lambda (name)
                (concatenate 'string name ":"))
              matches)
      matches)))


(defmethod complete-fragment (frag (type (eql :symbol-name)))
  (let ((parent (fragment-parent frag))
        matches)
    (dolist (symbol-type (fragment-types parent) matches)
      (case symbol-type
        (:local-symbol
          (setf matches
              (nconc matches
                     (complete-package (fragment-result frag) :include-marker t)
                     (complete-symbol (fragment-result frag)
                                      *package*
                                      '(:internal :external :inherited)))))
        (:external-symbol
          (setf matches
              (nconc matches
                     (complete-symbol (fragment-result frag)
                                      (find-package (fragment-result (first (fragment-children parent))))
                                      '(:external)))))
        (:internal-symbol
          (setf matches
              (nconc matches
                     (complete-symbol (fragment-result frag)
                                      (find-package (fragment-result (first (fragment-children parent))))
                                      '(:internal)))))))))


(defmethod complete-fragment (frag (type (eql :package-name)))
  (complete-package (fragment-result frag)))


(defmethod complete-fragment (frag (type (eql :package-marker)))
  (complete-fragment frag :symbol-name))


(defmethod jupyter:complete-code ((k kernel) code cursor-pos)
  (jupyter:inform :error k "~A ~A" code cursor-pos)
  (jupyter:handling-errors
    (when-let ((frag (locate-fragment code cursor-pos)))
      (values
        (sort
          (remove-duplicates
            (mapcan (lambda (type)
                      (complete-fragment frag type))
                    (fragment-types frag))
            :test #'string=)
          #'string-lessp)
        (fragment-start frag)
        (fragment-end frag)))))

    ; (with-input-from-string (stream code))
    ; (do ((stream
    ; (multiple-value-bind (word start end) (symbol-string-at-position code cursor-pos)
    ;   (when word
    ;     (values
    ;       (multiple-value-bind (name package-name ext) (split-qualified-name word)
    ;         (with-slots (package) k
    ;           (let ((pkg (find-package (or package-name package))))
    ;             (when pkg
    ;               (if ext
    ;                 (iter
    ;                   (for sym in-package pkg external-only t)
    ;                   (for sym-name next (symbol-name sym))
    ;                   (when (starts-with-subseq name sym-name)
    ;                     (collect
    ;                       (symbol-name-to-qualified-name sym-name package-name pkg))))
    ;                 (iter
    ;                   (for sym in-package pkg)
    ;                   (for sym-name next (symbol-name sym))
    ;                   (when (starts-with-subseq name sym-name)
    ;                     (collect
    ;                       (symbol-name-to-qualified-name sym-name package-name pkg)))))))))
    ;       start
    ;       end)))))

