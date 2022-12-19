(use spork)
(import ./git)
(import ./glob)
(import ./util)

######### TODO #########
# Add encryption       #
# Add node management  #
########################
# Add signing          #

(defn- create_dirs_if_not_exists [dir]
  (let [meta (os/stat dir)]
    (if (not (and meta (= (meta :mode) :directory)))
      (sh/create-dirs dir))))

(defn- generic/set [base-dir key value &named no-git commit-message ttl]
  (def formatted-key (path/join ;(path/posix/parts key)))
  (def path (path/join base-dir formatted-key))
  (def arch-dir (util/arch-dir))
  (def data @{:value value :ttl (if ttl (+ (os/time) ttl) nil)})
  (if (not value)
    (do
      (def path (path/join base-dir key))
      (default commit-message (string "store: deleted " key))
      (os/rm path)
      (unless no-git
        (git/loud arch-dir "reset")
        (git/loud arch-dir "add" "-f" path)
        (git/loud arch-dir "commit" "-m" commit-message)
        (git/async arch-dir "push")))
    (do
      (create_dirs_if_not_exists (path/join base-dir (path/dirname formatted-key)))
      (default commit-message (string "store: set " key " to " value))
      (spit path (string/format "%j" data))
      (unless no-git
        (git/loud arch-dir "reset")
        (git/loud arch-dir "add" "-f" path)
        (git/loud arch-dir "commit" "-m" commit-message)
        (git/async arch-dir "push")))))

(defn- generic/get [base-dir key &named check-signature check-ttl commit-message no-git]
  (default check-signature true)  # TODO check signature
  (default check-ttl true)
  # TODO decrypt if needed
  (def path (path/join base-dir (path/join ;(path/posix/parts key))))
  (let [stat (os/stat path)]
    (if (or (= stat nil) (not (= (stat :mode) :file)))
      nil # Key does not exist
      (let [data (parse (slurp path))]
        (if (not (data :value)) (error (string "malformed store at " key))) # TODO handle this error better ()
        (if (and (data :ttl) (< (data :ttl) (os/time)))
          (do
            (generic/set base-dir key nil :no-git no-git :commit-message (if commit-message commit-message (string "store: expired " key)))
            nil)
          (data :value))))))

(defn- generic/ls [base-dir &opt glob-pattern]
  (default glob-pattern ".")
  (create_dirs_if_not_exists base-dir)
  (def ret @[])
  (def prev (os/cwd))
  (os/cd base-dir)
  (if (or (string/find "*" glob-pattern)
          (string/find "?" glob-pattern))
    (let [pattern (glob/glob-to-peg glob-pattern)]
         (sh/scan-directory "." |(if (and (= ((os/stat $0) :mode) :file)
                                          (peg/match pattern $0))
                                     (array/push ret $0))))
    (let [glob-stat (os/stat glob-pattern)]
      (if (and glob-stat (= (glob-stat :mode) :directory))
          (do (sh/scan-directory glob-pattern |(if (= ((os/stat $0) :mode) :file) (array/push ret $0))))
          @[])))
  (os/cd prev)
  ret)

(defn- generic/ls-contents [base-dir glob-pattern &named no-git commit-message]
  (def ret @{})
  (each item (generic/ls base-dir glob-pattern)
    (put ret item (generic/get base-dir item :no-git no-git :commit-message commit-message)))
  ret)

(defn- get-config-dir [] (path/join (util/arch-dir) "config"))
(defn store/get [key &named commit-message] (generic/get (get-config-dir) key :commit-message commit-message))
(defn store/set [key value &named commit-message ttl] (generic/set (get-config-dir) key value :commit-message commit-message :ttl ttl))
(defn store/ls [&opt glob-pattern] (generic/ls (get-config-dir) glob-pattern))
(defn store/rm [key &named commit-message] (store/set key nil :commit-message commit-message))
(defn store/ls-contents [glob-pattern &named commit-message] (generic/ls-contents (get-config-dir) glob-pattern :commit-message commit-message))

(defn- get-cache-dir [] (path/join (util/arch-dir) ".git/glyph/cache"))
(defn cache/get [key] (generic/get (get-cache-dir) key :no-git true))
(defn cache/set [key value &named commit-message ttl] (generic/set (get-cache-dir) key value :no-git true :commit-message commit-message :ttl ttl))
(defn cache/ls [&opt glob-pattern] (generic/ls (get-cache-dir) glob-pattern))
(defn cache/rm [key] (cache/set key nil) :no-git true)
(defn cache/ls-contents [glob-pattern] (generic/ls-contents (get-cache-dir) glob-pattern :no-git true))
