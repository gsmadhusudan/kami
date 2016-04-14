Require Import Lts.Syntax Lts.Semantics Lts.Equiv Lts.Refinement Lts.Renaming Lts.Wf.
Require Import Lts.Inline Lts.InlineFacts_2.
Require Import Ex.SC Ex.ProcDec.

Set Implicit Arguments.

Section Inlined.
  Variables addrSize fifoSize valSize rfIdx: nat.

  Variable dec: DecT 2 addrSize valSize rfIdx.
  Variable exec: ExecT 2 addrSize valSize rfIdx.

  Definition pdec := pdecf fifoSize dec exec.
  Hint Unfold pdec: ModuleDefs. (* for kinline_compute *)

  Definition pdecInl: Modules * bool.
  Proof.
    remember (inlineF pdec) as inlined.
    kinline_compute_in Heqinlined.
    match goal with
    | [H: inlined = ?m |- _] =>
      exact m
    end.
  Defined.

  Lemma pdecInl_equal: pdecInl = inlineF pdec.
  Proof.
    kinline_compute.
    reflexivity.
  Qed.

End Inlined.
