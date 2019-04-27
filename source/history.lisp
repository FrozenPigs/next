;;; history.lisp --- manage and create bookmarks

(in-package :next)

(defun %initialize-history-db (path)
  "Create a database file if necessary and make a table for bookmarks"
  (close (open (ensure-parent-exists path)
               :direction :probe :if-does-not-exist :create))
  (let ((db (sqlite:connect
             (truename (probe-file path)))))
    (sqlite:execute-non-query
     db "create table history (id integer primary key, url text not null)")
    (sqlite:execute-non-query
     db "create table typed (id integer primary key, url text not null, visits integer default 1, unique (url) on conflict replace)")
    (sqlite:execute-non-query
     db "insert into history (url) values (?)" "about:blank")
    (sqlite:execute-non-query
     db "insert into typed (url) values (?)" "about:blank")
    (sqlite:disconnect db))
  (if (probe-file path)
      (let ((db (sqlite:connect
                 (truename (probe-file path)))))
        (unless (string= "visits" (cadar (last (sqlite:execute-to-list db "pragma table_info(typed)"))))
          (sqlite:execute-non-query db "alter table typed add visits integer default 1")))))

(defun ensure-history-db ()
  "Returns the pathname of the history database"
  (ensure-file-exists 
   (anaphora:aif (window-active *interface*)
                 (history-db-path anaphora:it)
                 ;;; FIXME: when we want to have multiple history-db
                 (some (lambda (window)
                         (history-db-path window))
                       (alexandria:hash-table-values (windows *interface*))))
   #'%initialize-history-db))
       
(defun history-add (url)
  (let ((db (sqlite:connect (ensure-history-db))))
    (sqlite:execute-non-query
     db "insert into history (url) values (?)" url)
    (sqlite:disconnect db)))

(defun history-typed-add (url)
  (let ((db (sqlite:connect (ensure-history-db))))
    (sqlite:execute-non-query
     db "insert into typed (url, visits) values (?, 1) on conflict (url) do update set visits = typed.visits + 1" url)
    (sqlite:disconnect db)))

(defun history-typed-complete (input)
  (let* ((db (sqlite:connect (ensure-history-db)))
         (candidates
          (sqlite:execute-to-list
           db "select url from typed where url like ? order by visits desc"
           (format nil "%~a%" input))))
    (sqlite:disconnect db)
    (reduce #'append candidates :from-end t)))
