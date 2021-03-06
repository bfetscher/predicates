#lang racket

(require rackunit
         "stlc.rkt")

;; e ::= (λ (x t) e) | (app e e) | (var x)
;;       | (if0 e e e) | true | false
;; t ::= bool | (t -> t)
;; env ::= () | ((x t) env)

(define (eval-stlc e)
  (match e
    ['true 'true]
    ['false 'false]
    [`(if0 ,t ,true ,false)
     (eval-if0 t true false)]
    [`(λ (,x ,t) ,ef)
     `(λ (,x ,t) ,ef)]
    [`(app ,f ,e1)
     (eval-stlc (eval-app f e1))]
    [`(var ,x)
     `(var ,x)]
    [else (error (format "Unknown exp: ~s" e))]))

(define (eval-app f e)
  (match (eval-stlc f)
    [`(λ (,x ,t) ,ef)
     (substitute x e ef)]
    [else
     (error (format "App without lambda: ~s ~s" f e))]))

(define (var-subst old new e)
  (define (old? v) (equal? old v))
  (match e
    [`(λ (,(? old? v) ,t) ,e1) e]
    [`(var ,(? old? v)) `(var ,new)]
    [`(,es ...)
     (for/list ([e es]) (var-subst old new e))]
    [else e]))

(define (substitute x e-subst e)
  (define (x? v) (equal? x v))
  (match e
    [`(λ (,(? x? v) ,t) ,e1) e]
    [`(λ (,y ,t) ,e1)
     (let ([var (gensym y)])
       `(λ (,var ,t) ,(substitute x e-subst (var-subst y var e1))))]
    [`(var ,(? x? v)) e-subst]
    [`(,es ...)
     (for/list ([e es]) (substitute x e-subst e))]
    [else e]))

(define (eval-if0 test true false)
  (match (eval-stlc test)
    ['true (eval-stlc true)]
    ['false (eval-stlc false)]
    [else (error (format "Conditional in if0 didn't evaluate: ~s" test))]))

(define (generate-eval-check n size)
  (for/and ([in-range n])
    (let* ([exp (generate-boolean size)]
           [res (eval-stlc (second (first exp)))]
           [ok (or (equal? res 'true)
                   (equal? res 'false))])
      (unless ok
        (pretty-print exp)
        (pretty-print res)
        #f))))
   

(check-equal?
 (eval-stlc '(if0 true true false))
 'true)

(check-equal?
 (eval-stlc '(if0
             (if0 true true false)
             (if0 false false true)
             false))
 'true)

(check-equal?
 (eval-stlc '(app (λ (x bool) true) true))
 'true)

(check-equal?
 (eval-stlc '(app (λ (x bool) (if0 (var x) false true)) true))
 'false)

(check-equal?
 (eval-stlc '(app 
              (app 
               (λ (x (bool -> bool)) (var x)) 
               (λ (x bool) (if0 (var x) true false)))
              true))
            'true)

(check-equal?
 (eval-stlc '(app (if0 true 
                      (λ (x_0 (t_1 -> t_1)) (app (λ (x_2 bool) (var x_2)) true))
                      (λ (x_3 (t_1 -> t_1)) true)) (λ (x_4 t_1) (var x_4))))
            'true)

(check-equal?
 (eval-stlc '(app
              (app
               (λ (y bool)
                 (app
                  (λ (x (bool -> bool))
                    (λ (y bool)
                      (app (var x) (var y))))
                  (λ (x bool)
                    (var y))))
               true)
              true))
 'true)

(check-exn
 exn:fail?
 (lambda () 
   (eval-stlc '(app
                (app
                 (λ (y bool)
                   (app
                    (λ (x (bool -> bool))
                      (λ (y bool)
                        (app (var y) (var y))))
                    (λ (x bool)
                      (var y))))
                 true)
                true))))
 
                 
              
(check-not-equal?
 (generate-eval-check 1000 20)
 #f)