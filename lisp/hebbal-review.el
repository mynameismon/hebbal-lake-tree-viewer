;;; hebbal-review.el --- Review Hebbal survey findings beside the PDF -*- lexical-binding: t; -*-

;; Usage: (load-file "/path/to/hebbal-lake-data/lisp/hebbal-review.el")
;;        M-x hebbal-review-issues

(require 'cl-lib)
(require 'image-mode)
(require 'json)
(require 'subr-x)
(require 'tabulated-list)

(declare-function pdf-view-goto-page "pdf-view" (page))

(defgroup hebbal-review nil
  "Review findings in the Hebbal tree survey."
  :group 'applications)

(defcustom hebbal-review-root
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Directory containing Bi-Directional.pdf, scripts/, and data/."
  :type 'directory
  :group 'hebbal-review)

(defcustom hebbal-review-python "python3"
  "Python executable used for the deterministic checker."
  :type 'string
  :group 'hebbal-review)

(defcustom hebbal-review-image-rotation 270
  "Degrees to rotate rendered PDF pages so the scanned tables are upright.
Set this to 0 if your copy of the PDF already displays upright."
  :type 'integer
  :group 'hebbal-review)

(defvar-local hebbal-review--findings nil)
(defvar-local hebbal-review--filter 'all)
(defvar-local hebbal-review--csv-window nil)
(defvar-local hebbal-review--pdf-window nil)
(defvar-local hebbal-review--issues-window nil)
(defvar-local hebbal-review--saved-window-config nil)

(defvar hebbal-review-image-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "H") #'image-scroll-right)
    (define-key map (kbd "L") #'image-scroll-left)
    (define-key map (kbd "<left>") #'image-scroll-right)
    (define-key map (kbd "<right>") #'image-scroll-left)
    map)
  "Large-step horizontal scrolling keys for rendered PDF pages.")

(define-minor-mode hebbal-review-image-mode
  "Use left/right arrows or H/L to pan the rendered PDF image."
  :lighter " Hebbal"
  :keymap hebbal-review-image-mode-map)

(defun hebbal-review--file (relative)
  (expand-file-name relative hebbal-review-root))

(defun hebbal-review--run-checker ()
  "Regenerate the findings files from the grouped CSVs."
  (let ((python (executable-find hebbal-review-python))
        (script (hebbal-review--file "scripts/check_tables.py")))
    (unless python
      (user-error "Cannot find %s; customize hebbal-review-python" hebbal-review-python))
    (unless (file-readable-p script)
      (user-error "Checker is missing: %s" script))
    (with-temp-buffer
      (let ((status (process-file python nil t nil script)))
        (unless (zerop status)
          (error "Hebbal checker failed: %s" (string-trim (buffer-string))))
        (string-trim (buffer-string))))))

(defun hebbal-review--load-findings ()
  "Load the checker JSON into the current issues buffer."
  (let ((path (hebbal-review--file "data/by_heading/check_findings.json"))
        (json-object-type 'alist)
        (json-array-type 'list)
        (json-key-type 'symbol))
    (unless (file-readable-p path)
      (user-error "No check report at %s; run M-x hebbal-review-issues" path))
    (setq hebbal-review--findings
          (alist-get 'findings (json-read-file path)))))

(defun hebbal-review--field (finding key)
  (or (alist-get key finding) ""))

(defun hebbal-review--print ()
  "Display findings that match the current filter."
  (setq tabulated-list-entries
        (cl-loop for finding in hebbal-review--findings
                 for id from 0
                 when (or (eq hebbal-review--filter 'all)
                          (equal (hebbal-review--field finding 'source)
                                 (symbol-name hebbal-review--filter)))
                 collect
                 (list id
                       (vector
                        (hebbal-review--field finding 'source_page)
                        (hebbal-review--field finding 'row_identifier)
                        (hebbal-review--field finding 'field)
                        (hebbal-review--field finding 'source)
                        (hebbal-review--field finding 'group)
                        (hebbal-review--field finding 'message)))))
  (tabulated-list-print t)
  (setq mode-line-process (format " [%s: %d]" hebbal-review--filter (length tabulated-list-entries))))

(defun hebbal-review--current ()
  (let ((id (tabulated-list-get-id)))
    (unless id (user-error "Move to a finding first"))
    (nth id hebbal-review--findings)))

(defun hebbal-review--render-page (pdf page)
  "Render PAGE of PDF to a cached image and return its filename."
  (let* ((converter (executable-find "pdftoppm"))
         (rotator (or (executable-find "magick")
                      (executable-find "convert")))
         (cache (expand-file-name
                 (format "hebbal-review-%s"
                         (substring (secure-hash 'sha1 (file-truename pdf)) 0 12))
                 temporary-file-directory))
         (prefix (expand-file-name (format "page-%d-raw" page) cache))
         (raw (concat prefix ".png"))
         (rotated (expand-file-name
                   (format "page-%d-rot%d.png" page hebbal-review-image-rotation)
                   cache))
         (target (if (and rotator (/= hebbal-review-image-rotation 0))
                     rotated raw)))
    (unless converter
      (user-error "Install pdftoppm or open the PDF in pdf-tools before jumping"))
    (make-directory cache t)
    (unless (and (file-readable-p target)
                 (file-newer-than-file-p target pdf))
      (with-temp-buffer
        (let ((status (process-file converter nil t nil
                                    "-f" (number-to-string page)
                                    "-l" (number-to-string page)
                                    "-r" "180" "-png" "-singlefile"
                                    pdf prefix)))
          (unless (zerop status)
            (error "Could not render PDF page %d: %s" page (string-trim (buffer-string))))))
      (when (and rotator (/= hebbal-review-image-rotation 0))
        (with-temp-buffer
          (let ((status (process-file rotator nil t nil raw "-rotate"
                                      (number-to-string hebbal-review-image-rotation)
                                      rotated)))
            (unless (zerop status)
              (error "Could not rotate PDF page %d: %s" page (string-trim (buffer-string))))))))
    target))

(defun hebbal-review--prepare-image (buffer window)
  "Fit BUFFER in WINDOW and install horizontal panning keys for zooming."
  (with-current-buffer buffer
    (when (derived-mode-p 'image-mode)
      (setq-local image-auto-resize-on-window-resize nil)
      (hebbal-review-image-mode 1)
      (with-selected-window window
        (image-transform-fit-both)
        (set-window-hscroll window 0)))))

(defun hebbal-review-visit ()
  "Show the source PDF page of the finding at point.
Keep the findings list selected so `n' and `p' can step through issues."
  (interactive)
  (let* ((finding (hebbal-review--current))
         (page-text (hebbal-review--field finding 'source_page))
         (page (string-to-number page-text))
         (pdf (hebbal-review--file "Bi-Directional.pdf")))
    (unless (> page 0)
      (user-error "This finding has no source page"))
    (unless (file-readable-p pdf)
      (user-error "PDF is missing: %s" pdf))
    (let* ((open-pdf (get-file-buffer pdf))
           (pdf-tools-p (and open-pdf
                             (with-current-buffer open-pdf
                               (derived-mode-p 'pdf-view-mode))))
           (_image-display-check
            (unless (or pdf-tools-p (display-images-p))
              (user-error "This Emacs display cannot show page images; use GUI Emacs")))
           (image (unless pdf-tools-p (hebbal-review--render-page pdf page)))
           (buffer (if pdf-tools-p open-pdf (find-file-noselect image)))
           (window (display-buffer buffer
                                   '((display-buffer-reuse-window
                                      display-buffer-pop-up-window)
                                     (inhibit-same-window . t)))))
      (unless window (user-error "Could not display the PDF"))
      (with-selected-window window
        (when pdf-tools-p (pdf-view-goto-page page)))
      (unless pdf-tools-p
        (hebbal-review--prepare-image buffer window))
      (message "PDF page %s · row %s · %s"
               page-text
               (hebbal-review--field finding 'row_identifier)
               (hebbal-review--field finding 'field)))))

(defun hebbal-review--step (delta)
  (forward-line delta)
  (unless (tabulated-list-get-id)
    (forward-line (- delta))
    (user-error "No more findings"))
  (hebbal-review-show-pair))

(defun hebbal-review-next ()
  "Move to the next finding and update its CSV and PDF views."
  (interactive)
  (hebbal-review--step 1))

(defun hebbal-review-previous ()
  "Move to the previous finding and update its CSV and PDF views."
  (interactive)
  (hebbal-review--step -1))

(defun hebbal-review-details ()
  "Show the full finding and printed table heading."
  (interactive)
  (let* ((finding (hebbal-review--current))
         (group (hebbal-review--field finding 'group))
         (heading-file (hebbal-review--file
                        (format "data/by_heading/%s/heading.txt" group))))
    (with-help-window "*Hebbal Finding*"
      (princ (format "Page: %s\nRow: %s\nField: %s\nSource: %s\nCode: %s\n\n%s\n"
                     (hebbal-review--field finding 'source_page)
                     (hebbal-review--field finding 'row_identifier)
                     (hebbal-review--field finding 'field)
                     (hebbal-review--field finding 'source)
                     (hebbal-review--field finding 'code)
                     (hebbal-review--field finding 'message)))
      (when (file-readable-p heading-file)
        (princ (format "\nPrinted heading:\n%s"
                       (with-temp-buffer
                         (insert-file-contents heading-file)
                         (buffer-string))))))))

(defun hebbal-review--csv-position (finding)
  "Return (POSITION . EXACT) for FINDING in the current CSV buffer.
An absent serial opens the nearest numbered row on the same PDF page."
  (let* ((page (hebbal-review--field finding 'source_page))
         (row (hebbal-review--field finding 'row_identifier))
         (serial (cond
                  ((string-match-p "\\`[0-9]+\\'" row) row)
                  ((string-match "\\`SL NO[[:space:]]+\\([0-9]+\\)" row)
                   (match-string 1 row))))
         (tree (when (string-match "\\`tree_no_\\([0-9]+[[:alpha:]]*\\)" row)
                 (match-string 1 row)))
         (pattern (cond
                   (serial (format "^%s,%s," (regexp-quote page)
                                   (regexp-quote serial)))
                   (tree (format "^%s,[^,]*,%s," (regexp-quote page)
                                 (regexp-quote tree)))))
         (best nil)
         (best-distance nil)
         (best-serial nil))
    (save-excursion
      (goto-char (point-min))
      (if (and pattern (re-search-forward pattern nil t))
          (cons (line-beginning-position) t)
        (goto-char (point-min))
        (while (re-search-forward
                (format "^%s,\\([^,]*\\)," (regexp-quote page)) nil t)
          (let ((candidate (match-string 1)))
            (when (string-match-p "\\`[0-9]+\\'" candidate)
              (let* ((number (string-to-number candidate))
                     (distance (if serial (abs (- number (string-to-number serial))) 0)))
                (when (or (null best-distance)
                          (< distance best-distance)
                          (and (= distance best-distance) (> number best-serial)))
                  (setq best (line-beginning-position)
                        best-distance distance
                        best-serial number))))))
        (when best (cons best nil))))))

(defun hebbal-review--show-table (select)
  "Show the finding's CSV row; select the CSV window when SELECT is non-nil."
  (let* ((finding (hebbal-review--current))
         (group (hebbal-review--field finding 'group))
         (page (hebbal-review--field finding 'source_page))
         (row (hebbal-review--field finding 'row_identifier))
         (path (hebbal-review--file
                (format "data/by_heading/%s/table.csv" group))))
    (unless (file-readable-p path)
      (user-error "Table CSV is missing: %s" path))
    (let* ((buffer (find-file-noselect path))
           (location (with-current-buffer buffer
                       (hebbal-review--csv-position finding))))
      (unless location
        (user-error "No CSV row on page %s for %s" page row))
      (let ((window (if select
                        (progn (pop-to-buffer buffer) (selected-window))
                      (display-buffer buffer
                                      '((display-buffer-reuse-window
                                         display-buffer-pop-up-window)
                                        (inhibit-same-window . t))))))
        (unless window (user-error "Could not display the table CSV"))
        (with-current-buffer buffer (goto-char (car location)))
        (set-window-point window (car location))
        (set-window-start window (car location))
        (unless (cdr location)
          (message "Row %s is absent on page %s; showing the nearest CSV row"
                   row page))))))

(defun hebbal-review-open-table ()
  "Open the CSV at the finding's row."
  (interactive)
  (hebbal-review--show-table t))

(defun hebbal-review--pan-image (rightward)
  "Pan the PDF image pane toward its right edge when RIGHTWARD is non-nil."
  (unless (window-live-p hebbal-review--pdf-window)
    (user-error "Open a finding with RET first"))
  (with-selected-window hebbal-review--pdf-window
    (unless (derived-mode-p 'image-mode)
      (user-error "The PDF pane is not a rendered image"))
    (if rightward (image-scroll-left) (image-scroll-right))))

(defun hebbal-review-pan-right ()
  "Show the next section to the right of the zoomed PDF image."
  (interactive)
  (hebbal-review--pan-image t))

(defun hebbal-review-pan-left ()
  "Show the previous section to the left of the zoomed PDF image."
  (interactive)
  (hebbal-review--pan-image nil))

(defun hebbal-review-show-pair ()
  "Show the finding's CSV row and PDF page beside each other.
Keep the findings list selected below them for `n' and `p'."
  (interactive)
  (let* ((finding (hebbal-review--current))
         (group (hebbal-review--field finding 'group))
         (page-text (hebbal-review--field finding 'source_page))
         (page (string-to-number page-text))
         (row (hebbal-review--field finding 'row_identifier))
         (issues-buffer (current-buffer))
         (csv-path (hebbal-review--file
                    (format "data/by_heading/%s/table.csv" group)))
         (pdf-path (hebbal-review--file "Bi-Directional.pdf")))
    (unless (> page 0)
      (user-error "This finding has no PDF page"))
    (unless (file-readable-p csv-path)
      (user-error "Table CSV is missing: %s" csv-path))
    (unless (file-readable-p pdf-path)
      (user-error "PDF is missing: %s" pdf-path))
    (let* ((csv-buffer (find-file-noselect csv-path))
           (location (with-current-buffer csv-buffer
                       (hebbal-review--csv-position finding)))
           (open-pdf (get-file-buffer pdf-path))
           (pdf-tools-p (and open-pdf
                             (with-current-buffer open-pdf
                               (derived-mode-p 'pdf-view-mode)))))
      (unless location
        (user-error "No CSV row on page %s for %s" page-text row))
      (unless (or pdf-tools-p (display-images-p))
        (user-error "This Emacs display cannot show page images; use GUI Emacs"))
      (let ((pdf-buffer (if pdf-tools-p open-pdf
                          (find-file-noselect
                           (hebbal-review--render-page pdf-path page)))))
        (unless (and (window-live-p hebbal-review--csv-window)
                     (window-live-p hebbal-review--pdf-window)
                     (window-live-p hebbal-review--issues-window)
                     (eq (window-buffer hebbal-review--issues-window)
                         issues-buffer))
          (unless hebbal-review--saved-window-config
            (setq hebbal-review--saved-window-config
                  (current-window-configuration)))
          (delete-other-windows (selected-window))
          (let* ((left (selected-window))
                 (bottom (split-window left
                                       (max 8 (floor (* 0.65 (window-total-height left))))
                                       'below))
                 (right (split-window left nil 'right)))
            (setq hebbal-review--csv-window left
                  hebbal-review--pdf-window right
                  hebbal-review--issues-window bottom)
            (set-window-buffer bottom issues-buffer)))
        (set-window-buffer hebbal-review--csv-window csv-buffer)
        (let ((previous-pdf-buffer (window-buffer hebbal-review--pdf-window)))
          (set-window-buffer hebbal-review--pdf-window pdf-buffer)
          (unless (or pdf-tools-p (eq previous-pdf-buffer pdf-buffer))
            (hebbal-review--prepare-image pdf-buffer hebbal-review--pdf-window)))
        (with-current-buffer csv-buffer (goto-char (car location)))
        (set-window-point hebbal-review--csv-window (car location))
        (set-window-start hebbal-review--csv-window (car location))
        (when pdf-tools-p
          (with-selected-window hebbal-review--pdf-window
            (pdf-view-goto-page page)))
        (select-window hebbal-review--issues-window)
        (message "CSV row %s and PDF page %s%s"
                 row page-text (if (cdr location) "" " (nearest CSV row)"))))))

(defun hebbal-review-quit ()
  "Restore the window layout from before the side-by-side review view."
  (interactive)
  (let ((configuration hebbal-review--saved-window-config))
    (setq hebbal-review--saved-window-config nil
          hebbal-review--csv-window nil
          hebbal-review--pdf-window nil
          hebbal-review--issues-window nil)
    (if configuration
        (set-window-configuration configuration)
      (quit-window))))

(defun hebbal-review--set-filter (filter)
  (setq hebbal-review--filter filter)
  (hebbal-review--print)
  (goto-char (point-min)))

(defun hebbal-review-show-all ()
  "Show manual notes and automatic findings."
  (interactive)
  (hebbal-review--set-filter 'all))

(defun hebbal-review-show-automatic ()
  "Show only deterministic checker findings."
  (interactive)
  (hebbal-review--set-filter 'automatic))

(defun hebbal-review-show-manual ()
  "Show only the original visual review notes."
  (interactive)
  (hebbal-review--set-filter 'manual))

(defun hebbal-review-refresh ()
  "Rerun the checker and refresh the findings list."
  (interactive)
  (let ((summary (hebbal-review--run-checker)))
    (hebbal-review--load-findings)
    (hebbal-review--print)
    (message "%s" summary)))

(defvar hebbal-review-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") #'hebbal-review-show-pair)
    (define-key map (kbd "n") #'hebbal-review-next)
    (define-key map (kbd "p") #'hebbal-review-previous)
    (define-key map (kbd "d") #'hebbal-review-details)
    (define-key map (kbd "v") #'hebbal-review-open-table)
    (define-key map (kbd "o") #'hebbal-review-visit)
    (define-key map (kbd "q") #'hebbal-review-quit)
    (define-key map (kbd "H") #'hebbal-review-pan-left)
    (define-key map (kbd "L") #'hebbal-review-pan-right)
    (define-key map (kbd "g") #'hebbal-review-refresh)
    (define-key map (kbd "a") #'hebbal-review-show-automatic)
    (define-key map (kbd "m") #'hebbal-review-show-manual)
    (define-key map (kbd "s") #'hebbal-review-show-all)
    map)
  "Keymap for `hebbal-review-mode'.")

(define-derived-mode hebbal-review-mode tabulated-list-mode "Hebbal Review"
  "Browse findings with their CSV rows and PDF pages side by side."
  (setq tabulated-list-format
        [("Page" 5 t)
         ("Row" 18 t)
         ("Field" 22 t)
         ("Source" 10 t)
         ("Group" 38 t)
         ("Finding" 100 t)])
  (setq tabulated-list-padding 2)
  (setq truncate-lines t)
  (tabulated-list-init-header))

;;;###autoload
(defun hebbal-review-issues (&optional skip-check)
  "Run the checker and open the findings browser.
With prefix argument SKIP-CHECK, show the most recent report instead."
  (interactive "P")
  (unless skip-check (hebbal-review--run-checker))
  (let ((buffer (get-buffer-create "*Hebbal Review*")))
    (with-current-buffer buffer
      (hebbal-review-mode)
      (hebbal-review--load-findings)
      (hebbal-review--print)
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

(provide 'hebbal-review)
;;; hebbal-review.el ends here
