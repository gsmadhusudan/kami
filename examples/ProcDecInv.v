Require Import Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word.
Require Import Lib.Struct Lib.StringBound Lib.FMap Lib.StringEq Lib.Indexer.
Require Import Lts.Syntax Lts.Semantics Lts.Equiv Lts.Refinement Lts.Renaming Lts.Wf.
Require Import Lts.Renaming Lts.Specialize Lts.Inline Lts.InlineFacts_2 Lts.DecompositionZero.
Require Import Lts.Tactics.
Require Import Ex.SC Ex.Fifo Ex.MemAtomic Ex.ProcDec Ex.ProcDecInl.
Require Import Eqdep ProofIrrelevance.

Set Implicit Arguments.

Definition or3 (b1 b2 b3: Prop) := b1 \/ b2 \/ b3.
Tactic Notation "or3_fst" := left.
Tactic Notation "or3_snd" := right; left.
Tactic Notation "or3_thd" := right; right.
Ltac dest_or3 :=
  match goal with
  | [H: or3 _ _ _ |- _] => destruct H as [|[|]]
  end.
Ltac kinv_or3 :=
  repeat
    match goal with
    | [H: or3 _ _ _ |- _] => dest_or3; kinv_contra
    end.

Section Invariants.
  Variables addrSize fifoSize valSize rfIdx: nat.

  Variable dec: DecT 2 addrSize valSize rfIdx.
  Variable exec: ExecT 2 addrSize valSize rfIdx.

  Definition pdecInl := pdecInl fifoSize dec exec.

  Definition procDec_inv_0 (o: RegsT): Prop.
  Proof.
    kexistv "pc"%string pcv o (Bit addrSize).
    kexistv "rf"%string rfv o (Vector (Bit valSize) rfIdx).
    kexistv "stall"%string stallv o Bool.
    kexistv "Ins".."empty"%string iev o Bool.
    kexistv "Ins".."full"%string ifv o Bool.
    kexistv "Ins".."enqP"%string ienqpv o (Bit fifoSize).
    kexistv "Ins".."deqP"%string ideqpv o (Bit fifoSize).
    kexistv "Ins".."elt"%string ieltv o (Vector (memAtomK addrSize valSize) fifoSize).
    kexistv "Outs".."empty"%string oev o Bool.
    kexistv "Outs".."full"%string ofv o Bool.
    kexistv "Outs".."enqP"%string oenqpv o (Bit fifoSize).
    kexistv "Outs".."deqP"%string odeqpv o (Bit fifoSize).
    kexistv "Outs".."elt"%string oeltv o (Vector (memAtomK addrSize valSize) fifoSize).
    exact True.
  Defined.
  Hint Unfold procDec_inv_0: InvDefs.

  Definition fifo_empty_inv (fifoEmpty: bool) (fifoEnqP fifoDeqP: type (Bit fifoSize)): Prop :=
    fifoEmpty = true /\ fifoEnqP = fifoDeqP.
  
  Definition fifo_not_empty_inv (fifoEmpty: bool) (fifoEnqP fifoDeqP: type (Bit fifoSize)): Prop :=
    fifoEmpty = false /\ fifoEnqP = fifoDeqP ^+ $1.

  Definition mem_request_inv
             (pc: fullType type (SyntaxKind (Bit addrSize)))
             (rf: fullType type (SyntaxKind (Vector (Bit valSize) rfIdx)))
             (insEmpty: bool) (insElt: type (Vector (memAtomK addrSize valSize) fifoSize))
             (insDeqP: type (Bit fifoSize)): Prop.
  Proof.
    refine (if insEmpty then True else _).
    refine (_ /\ _ /\ _).
    - exact (insElt insDeqP ``"type" = dec _ rf pc ``"opcode").
    - exact (insElt insDeqP ``"addr" = dec _ rf pc ``"addr").
    - refine (if weq (insElt insDeqP ``"type") (evalConstT memLd) then _ else _).
      + exact (insElt insDeqP ``"value" = evalConstT (getDefaultConst (Bit valSize))).
      + refine (if weq (insElt insDeqP ``"type") (evalConstT memSt) then _ else True).
        exact (insElt insDeqP ``"value" = dec _ rf pc ``"value").
  Defined.
  Hint Unfold fifo_empty_inv fifo_not_empty_inv mem_request_inv: InvDefs.

  Definition procDec_inv_1 (o: RegsT): Prop.
  Proof.
    kexistv "pc"%string pcv o (Bit addrSize).
    kexistv "rf"%string rfv o (Vector (Bit valSize) rfIdx).
    kexistv "stall"%string stallv o Bool.
    kexistv "Ins".."empty"%string iev o Bool.
    kexistv "Ins".."enqP"%string ienqP o (Bit fifoSize).
    kexistv "Ins".."deqP"%string ideqP o (Bit fifoSize).
    kexistv "Ins".."elt"%string ieltv o (Vector (memAtomK addrSize valSize) fifoSize).
    kexistv "Outs".."empty"%string oev o Bool.
    kexistv "Outs".."enqP"%string oenqP o (Bit fifoSize).
    kexistv "Outs".."deqP"%string odeqP o (Bit fifoSize).
    refine (or3 _ _ _).
    - exact (v1 = false /\ fifo_empty_inv v2 v3 v4 /\ fifo_empty_inv v6 v7 v8).
    - refine (_ /\ _).
      + exact (v1 = true /\ fifo_not_empty_inv v2 v3 v4 /\ fifo_empty_inv v6 v7 v8).
      + exact (mem_request_inv v v0 v2 v5 v4).
    - exact (v1 = true /\ fifo_empty_inv v2 v3 v4 /\ fifo_not_empty_inv v6 v7 v8).
  Defined.
  Hint Unfold procDec_inv_1: InvDefs.

  Lemma procDec_inv_0_ok':
    forall init n ll,
      init = initRegs (getRegInits (fst pdecInl)) ->
      Multistep (fst pdecInl) init n ll ->
      procDec_inv_0 n.
  Proof.
    admit.
    (* induction 2. *)

    (* - kinv_magic. *)

    (* - kinvert. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
    (*   + kinv_magic. *)
  Qed.

  Lemma procDec_inv_0_ok:
    forall o,
      reachable o (fst pdecInl) ->
      procDec_inv_0 o.
  Proof.
    intros; inv H; inv H0.
    eapply procDec_inv_0_ok'; eauto.
  Qed.

  Lemma procDec_inv_1_ok':
    forall init n ll,
      init = initRegs (getRegInits (fst pdecInl)) ->
      Multistep (fst pdecInl) init n ll ->
      procDec_inv_1 n.
  Proof.
    (*
    induction 2.

    - kinv_magic_with kinv_or3.
      or3_fst; kinv_magic.

    - kinvert.
      + kinv_magic_with kinv_or3.
      + kinv_magic_with kinv_or3.
      + kinv_magic_with kinv_or3.
        or3_snd; kinv_magic.
      + kinv_magic_with kinv_or3.
        or3_snd; kinv_magic.
      + kinv_magic_with kinv_or3.
        or3_fst; kinv_magic.
      + kinv_magic_with kinv_or3.
        or3_fst; kinv_magic.
      + kinv_magic_with kinv_or3.
        (* or3_fst; kinv_magic. *)
      + kinv_magic_with kinv_or3.
        or3_fst; kinv_magic.
      + kinv_magic_with kinv_or3.
        or3_thd; kinv_magic.
      + kinv_magic_with kinv_or3.
        or3_thd; kinv_magic.
     *)
    admit.
  Qed.

  Lemma procDec_inv_1_ok:
    forall o,
      reachable o (fst pdecInl) ->
      procDec_inv_1 o.
  Proof.
    intros; inv H; inv H0.
    eapply procDec_inv_1_ok'; eauto.
  Qed.

End Invariants.

Hint Unfold procDec_inv_0 procDec_inv_1
     fifo_empty_inv fifo_not_empty_inv mem_request_inv: InvDefs.

