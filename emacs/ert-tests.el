(ert-deftest get-signal-arrow ()
  "Test `icglue-get-signal-arrow` to detect various arrow forms"
  (should (equal (icglue-get-signal-arrow "S a_b src -> dst")   (list  9 13)))
  (should (equal (icglue-get-signal-arrow "S a_b src --> dst")  (list  9 14)))
  (should (equal (icglue-get-signal-arrow "S a_b src ---> dst") (list  9 15)))
  (should (equal (icglue-get-signal-arrow "S a_b src <- dst")   (list  9 13)))
  (should (equal (icglue-get-signal-arrow "S a_b src <-- dst")  (list  9 14)))
  (should (equal (icglue-get-signal-arrow "S a_b src <--- dst") (list  9 15)))
  (should (equal (icglue-get-signal-arrow "S a_b src <-> dst")   (list 9 14)))
  (should (equal (icglue-get-signal-arrow "S a_b src <--> dst")  (list 9 15)))
  (should (equal (icglue-get-signal-arrow "S a_b src <---> dst") (list 9 16)))
  (should (equal (icglue-get-signal-arrow "S a_b src -- dst") nil)))

(ert-deftest flip-arrow ()
  "Test basic arrow flip function"
  ;; basic shapes
  (should (equal (icglue-flip-arrow "->")    "<-"))
  (should (equal (icglue-flip-arrow "<-")    "->"))
  (should (equal (icglue-flip-arrow "<->")   "<->"))
  (should (equal (icglue-flip-arrow "-->")   "<--"))
  (should (equal (icglue-flip-arrow "<--")   "-->"))
  (should (equal (icglue-flip-arrow "<-->")  "<-->"))
  ;; handle whitespaces
  (should (equal (icglue-flip-arrow " -> ")  " <- "))
  (should (equal (icglue-flip-arrow " <- ")  " -> "))
  (should (equal (icglue-flip-arrow " <-> ") " <-> ")))

(ert-deftest flip-arrow-line ()
  "Check if arrow is correctly flipped for a complete line.
   cl-letf is used to mockup thing-at-point function."
  (cl-letf (((symbol-function 'thing-at-point) (lambda (&rest _)
                                                 "S name -w 4 src_mod --> dest_mod2")))
    (should (equal (icglue-get-flipped-arrow) "S name -w 4 src_mod <-- dest_mod2")))
   (cl-letf (((symbol-function 'thing-at-point) (lambda (&rest _)
                                                  "S name -w 4 src_mod <-- dest_mod2")))
     (should (equal (icglue-get-flipped-arrow) "S name -w 4 src_mod --> dest_mod2")))
   (cl-letf (((symbol-function 'thing-at-point) (lambda (&rest _)
                                                  "S name -w 4 src_mod <--> dest_mod2")))
     (should (equal (icglue-get-flipped-arrow) "S name -w 4 src_mod <--> dest_mod2"))))


