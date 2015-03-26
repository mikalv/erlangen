;;;; Basic tests for agents.

(defpackage erlangen.agent-test
  (:use :cl
        :erlangen.agent
        :erlangen.mailbox)
  (:export :run-tests))

(in-package :erlangen.agent-test)

(defun receive-timeout (&optional (seconds 1) (interval 1/10))
  (flet ((message-available-p ()
           (not (empty-p (erlangen.agent::agent-mailbox (agent))))))
    (loop repeat (/ seconds interval)
       if (message-available-p) do (return-from receive-timeout (receive))
       else do (sleep interval)))
  (error "Timeout in RECEIVE-TIMEOUT."))

(defmacro with-pseudo-agent ((var &key (mailbox-size 64)) &body body)
  `(let* ((,var (erlangen.agent::make-agent%
                 :mailbox (make-mailbox ,mailbox-size)))
          (erlangen.agent::*agent* ,var))
     ,@body))

(defun test-send-receive ()
  (with-pseudo-agent (p)
    (let ((relay (spawn (lambda () (send (receive) p)))))
      (spawn (lambda () (send :hello relay))))
    (assert (eq :hello (receive-timeout)) nil "SEND/RECEIVE failed.")))

(defun test-monitor-kill ()
  (with-pseudo-agent (p)
    (let ((monitored (spawn (lambda () (receive)) :attach :monitor)))
      (exit :kill monitored)
      (assert (equal `(,monitored :exit . :kill) (receive-timeout)) nil
              "Monitor received corrupted message."))))

(defun test-link ()
  (with-pseudo-agent (p)
    (let ((parent (spawn (lambda ()
                           (spawn (lambda () (+ 1 2 3)) :attach :link)
                           (receive))
                         :attach :monitor)))
      (assert (equal `(,parent :exit :ok 6) (receive-timeout)) nil
              "Monitor received corrupt message."))))

(defun test-send-error-killed ()
  (with-pseudo-agent (p)
    (let ((agent (spawn (lambda () (receive)))))
      (exit :kill agent)
      (handler-case (send :test agent)
        (send-error (error)
          error)
        (:no-error ()
          (error "SEND to exited agent did not signal SEND-ERROR.")))
      (handler-case (exit :test agent)
        (send-error (error)
          error)
        (:no-error ()
          (error "EXIT to exited agent did not signal SEND-ERROR."))))))

(defun run-tests ()
  (test-send-receive)
  (test-monitor-kill)
  (test-link)
  (test-send-error-killed))
