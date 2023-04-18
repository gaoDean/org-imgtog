;;; org-imgtog.el --- Auto-toggle inline images in org-mode -*- lexical-binding: t -*-

;; Copyright (C) 2023 Dean Gao - MIT License
;; Author: Dean Gao <gao.dean@hotmail.com>
;; Description: Automatically toggle Org mode inline images as your cursor enters and exits them.
;; Homepage: https://github.com/gaoDean/org-imgtog
;; Package-Requires: ((emacs "27.1"))

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This package automates toggling Org mode inline images much like org-fragtog.
;; Inline images are hidden for editing when your cursor steps onto them, and
;; re-enabled when the cursor leaves.

;;; Code:

(require 'org)
(require 'org-element)

(defgroup org-imgtog nil
  "Auto toggle inline images in org-mode."
  :group 'org)

(defcustom org-imgtog-preview-delay 0.0
  "Seconds of delay before image is toggled."
  :group 'org-imgtog
  :type 'number)

(defcustom org-imgtog-preview-delay-only-remote nil
  "Only apply preview delay to remote inline images.
If nil, apply to all images.
This is for users of the Doom emacs remote inline
image patch. For my plugin org-remoteimg, this is
not needed as the image is cached."
  :group 'org-imgtog
  :type 'boolean)

(defvar-local org-imgtog--prev-hidden-img-elem nil
  "The previous image that was hidden")

;;;###autoload
(define-minor-mode org-imgtog-mode
  "A minor mode that automatically toggles Org mode inline images.
They are hidden when your cursor steps onto them for easier editing,
and shown after your cursor leaves."
  :init-value nil

  ;; Fix nil error in `org-element-context'
  ;; when using `org-imgtog' without Org mode.
  ;; Taken from org-fragtog
  (setq org-complex-heading-regexp (or org-complex-heading-regexp ""))

  (if org-imgtog-mode
      (add-hook 'post-command-hook #'org-imgtog--post-cmd nil t)
    (remove-hook 'post-command-hook #'org-imgtog--post-cmd t)))

(defun org-imgtog--remote-image-p ()
  "Check if the point is on a remote image."
  (let ((elem (org-element-context))
        (image-file-regex (image-file-name-regexp)))
    (and (eq (car elem) 'link)
         (or (string= (org-element-property :type elem) "http")
             (string= (org-element-property :type elem) "https"))
         (string-match-p image-file-regex (org-element-property :path elem)))))

(defun org-imgtog--on-image-p ()
  "Check if the point is on an image. Returns element context"
  (let ((elem (org-element-context))
        (image-file-regex (image-file-name-regexp)))
    (and (eq (car elem) 'link)
         (or (string= (org-element-property :type elem) "file")
             (string= (org-element-property :type elem) "http")
             (string= (org-element-property :type elem) "https"))
         (string-match-p image-file-regex (org-element-property :path elem))
         (org-element-context))))

(defun org-imgtog--img-point (elem)
  "Gets the beginging and end of the image under the cursor"
  (let* ((start (org-element-property :begin elem))
         (end (org-element-property :end elem)))
    (cons start end)))

(defun org-imgtog--hide-img (elem)
  "Hide the image at point"
  (setq org-imgtog--prev-hidden-img-elem elem)

  (when (not (xor (> org-imgtog-preview-delay 0) (org-imgtog--on-image-p)))
    (let ((start-end (org-imgtog--img-point elem)))
      (org-remove-inline-images (car start-end) (cdr start-end)))))

(defun org-imgtog--show-img (elem)
  "Show the image at point"
  (setq org-imgtog--prev-hidden-img-elem nil)

  (let ((start-end (org-imgtog--img-point elem)))
    (org-display-inline-images nil nil (car start-end) (cdr start-end))))

(defun org-imgtog--hide-img-with-delay (elem)
  (run-with-timer org-imgtog-preview-delay
                  nil
                  #'org-imgtog--hide-img
                  elem))
  
(defun org-imgtog--post-cmd ()
  "Runs after `post-command-hook`. Handles toggling.
Image hidden and cursor not on image -> show image
Image not hidden and cursor on image -> hide image"
  (let ((hidden-img org-imgtog--prev-hidden-img-elem) ;; is there a hidden image
        (cursor-on-img (org-imgtog--on-image-p))) ;; is cursor on image

    (when (and hidden-img (not cursor-on-img))
      (org-imgtog--show-img hidden-img))

    (when (and cursor-on-img (not hidden-img))
      (cond ((and
              (> org-imgtog-preview-delay 0)
              org-imgtog-preview-delay-only-remote
              (org-imgtog--remote-image-p))
             (org-imgtog--hide-img-with-delay cursor-on-img))
            ((and
              (> org-imgtog-preview-delay 0)
              (not org-imgtog-preview-delay-only-remote))
             (org-imgtog--hide-img-with-delay cursor-on-img))
            (t (org-imgtog--hide-img cursor-on-img))))))
             

(provide 'org-imgtog)

;;; org-imgtog.el ends here
