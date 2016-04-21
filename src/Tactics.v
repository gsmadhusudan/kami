Require Import Bool String List.
Require Import Lib.CommonTactics Lib.Word Lib.StringBound Lib.Struct Lib.StringEq Lib.FMap.
Require Import Lts.Syntax Lts.Semantics Lts.SemFacts Lts.Wf Lts.Equiv Lts.Refinement.
Require Import Lts.Inline Lts.InlineFacts_2 Lts.Specialize.
Require Import Lts.Decomposition Lts.DecompositionZero.

Set Implicit Arguments.

(**
- Kami Tactics
  + kequiv : prove any PHOAS equivalences defined in src/Equiv.v
  + kequiv_with _tactic_ : also try to apply _tactic_ alternately
  + kvalid_regs : prove a well-formedness condition for valid register uses
  + kinline_compute : compute terms with _inlineF_
  + kinline_compute_in _term_ : compute terms with _inlineF_ in _term_
  + kinline_left : convert (a <<== b) to (inlineF a <<== b), where (inlineF a) is computed
  + kdecompose : apply the decomposition theorem
  + kdecompose_nodefs : apply the decompositionZero theorem,
    for modules with no defined methods.
  + kduplicated : convert (duplicate a <<== duplicate b) to (a <<== b)
  + kgetv/kexistv : used to construct register or label mappings

  + kinvert : invert Kami semantic definitions (Substep, Step, etc.)
  + kinv_magic : try to solve invariant proofs
    * kinv_simpl : simplify invariants
    * kinv_red : reduce invariants
    * kinv_contra : try to prove exfalso with invariants
    * kinv_finish : try to prove invariants.
  + kinv_magic_with _tactic_ : also try to apply _tactic_ alternately

- Kami Hints
  + Hint Extern 1 (Specializable _) => vm_compute; reflexivity.
  + Hint Extern 1 (ValidRegsModules _ _) => kvalid_regs.
  + Hint Extern 1 (SubList (getExtMeths _) (getExtMeths _)) => vm_compute; tauto.
  + Hint Extern 1 (_ (initRegs _) = initRegs _) => kdecompose_regmap_init.
 *)

Ltac kequiv_with tac :=
  repeat autounfold with MethDefs;
  repeat
    (try tac;
     match goal with
     | [ |- ModEquiv _ _ _ ] => constructor; intros
     | [ |- RulesEquiv _ _ _ ] => constructor; intros
     | [ |- MethsEquiv _ _ _ ] => constructor; intros
     | [ |- ActionEquiv _ _ _ ] => constructor; intros
     | [ |- ExprEquiv _ _ _ ] => constructor; intros
     | [ |- @ExprEquiv _ _ _ ?fk (ReadField ?a _) (ReadField ?a _) ] =>
       change fk with (SyntaxKind (GetAttrType a)); constructor; intros
     | [ |- In _ _] => simpl; tauto
     end).

Ltac kequiv := kequiv_with idtac.

Ltac kvalid_regs :=
  repeat autounfold with MethDefs;
  repeat
    match goal with
    | [ |- ValidRegsModules _ _ ] => constructor; intros
    | [ |- ValidRegsRules _ _ _ ] => constructor; intros
    | [ |- ValidRegsDms _ _ _ ] => constructor; intros
    | [ |- ValidRegsAction _ _ ] => constructor; intros
    | [ |- In _ _] => simpl; tauto
    end.

Ltac kinline_compute :=
  repeat autounfold with ModuleDefs;
  repeat autounfold with MethDefs;
  cbv [inlineF inline inlineDms inlineDms'
               inlineDmToMod inlineDmToRules inlineDmToRule
               inlineDmToDms inlineDmToDm inlineDm
               filterDms filter
               noInternalCalls noCalls
               noCallsRules noCallsDms noCallDm isLeaf
               getBody inlineArg
               appendAction getAttribute
               makeModule makeModule'
               wfModules wfRules wfDms wfAction wfActionC maxPathLength
               getRegInits getDefs getDefsBodies getRules namesOf
               map app attrName attrType
               getCalls getCallsR getCallsM getCallsA
               appendName append
               ret arg fst snd projT1 projT2
               string_in string_eq ascii_eq
               eqb existsb andb orb negb];
  repeat
    match goal with
    | [ |- context[SignatureT_dec ?s ?s] ] =>
      rewrite (signature_eq s); unfold eq_rect
    end.

Ltac kinline_compute_in H :=
  repeat autounfold with ModuleDefs in H;
  repeat autounfold with MethDefs in H;
  cbv [inlineF inline inlineDms inlineDms'
               inlineDmToMod inlineDmToRules inlineDmToRule
               inlineDmToDms inlineDmToDm inlineDm
               filterDms filter
               noInternalCalls noCalls
               noCallsRules noCallsDms noCallDm isLeaf
               getBody inlineArg
               appendAction getAttribute
               makeModule makeModule'
               wfModules wfRules wfDms wfAction wfActionC maxPathLength
               getRegInits getDefs getDefsBodies getRules namesOf
               map app attrName attrType
               getCalls getCallsR getCallsM getCallsA
               appendName append
               ret arg fst snd projT1 projT2
               string_in string_eq ascii_eq
               eqb existsb andb orb negb] in H;
  repeat
    match type of H with
    | context[SignatureT_dec ?s ?s] =>
      rewrite (signature_eq s) in H; unfold eq_rect in H
    end.

Ltac kinline_left im :=
  match goal with
  | [ |- traceRefines _ ?lm _ ] =>
    apply traceRefines_inlining_left; auto;
    let Heq := fresh "Heq" in
    remember (inlineF lm) as im eqn:Heq;
    kinline_compute_in Heq;
    split; [|subst; reflexivity]
  end.

Ltac kdecompose t r Hrm Hmm :=
  eapply decomposition with (theta:= t)
                              (ruleMap:= r)
                              (substepRuleMap:= Hrm)
                              (substepMethMap:= Hmm); auto; intros.

Ltac kregmap_red :=
  repeat autounfold with MethDefs in *;
  repeat
    (try match goal with
         | [H: M.find ?k ?m = _ |- context[M.find ?k ?m] ] => rewrite H
         | [ |- context[decKind ?k ?k] ] =>
           rewrite kind_eq; unfold eq_rect_r, eq_rect, eq_sym
         end;
     dest; try subst; try findReify);
  repeat
    match goal with
    | [H: M.find _ _ = _ |- _] => clear H
    end.

Ltac kdecompose_regmap_init :=
  unfold initRegs, getRegInits; simpl;
  kregmap_red; reflexivity.

Ltac kdecompose_nodefs t r :=
  apply decompositionZero with (theta:= t) (ruleMap:= r); intros; subst;
  try reflexivity; (* "getDefsBodies _ = nil" conditions *)
  auto. (* kdecompose_regMap_init *)

Ltac kinv_add inv :=
  let H := fresh "H" in
  pose proof inv as H;
  match goal with
  | [Hr: reachable _ _ |- _] => specialize (H _ _ _ _ _ _ _ Hr)
  end.

Ltac kinv_add_end :=
  match goal with
  | [H: reachable _ _ |- _] => clear H
  end.

Ltac kinvert :=
  repeat
    match goal with
    | [H1: ?t, H2: ?t -> _ |- _] => specialize (H2 H1)
    | [H: Substep _ _ _ _ _ |- _] => inv H; CommonTactics.dest_in
    | [H: Step _ _ _ _ |- _] =>
      apply stepZero in H; [|reflexivity]; destruct H
    end.

Ltac kinv_contra :=
  try (exfalso;
       repeat autounfold with InvDefs in *; dest; subst;
       repeat
         (match goal with
          | [H: false = true |- _] => inversion H
          | [H: true = false |- _] => inversion H
          | [H: negb _ = true |- _] => apply negb_true_iff in H; subst
          | [H: negb _ = false |- _] => apply negb_false_iff in H; subst
          end; dest; try subst);
       fail).

Ltac kinv_simpl :=
  repeat
    (try match goal with
         | [H: ?t = ?t |- _] => clear H
         | [H: negb _ = true |- _] => apply negb_true_iff in H; subst
         | [H: negb _ = false |- _] => apply negb_false_iff in H; subst
         | [ |- context [weq ?w ?w] ] =>
           let n := fresh "n" in destruct (weq w w) as [|n]; [|elim n; reflexivity]
         | [H: context [weq ?w ?w] |- _] =>
           let n := fresh "n" in destruct (weq w w) as [|n]; [|elim n; reflexivity]
         | [H: (if ?c then true else false) = true |- _] => destruct c; [|inv H]
         | [H: (if ?c then true else false) = false |- _] => destruct c; [inv H|]
         | [H: (if ?c then false else true) = true |- _] => destruct c; [inv H|]
         | [H: (if ?c then false else true) = false |- _] => destruct c; [|inv H]
         | [H1: M.find ?k ?m = _, H2: M.find ?k ?m = _ |- _] => rewrite H1 in H2
         | [H: Some _ = Some _ |- _] => inv H; destruct_existT
         end; dest; try subst).

Ltac kinv_red :=
  repeat autounfold with InvDefs in *;
  dest; try subst; kinv_simpl.

Ltac kinv_finish :=
  unfold IndexBound_head, IndexBound_tail in *; simpl in *;
  repeat
    (try match goal with
         | [H: _ = _ |- _] => rewrite H in *; simpl in *; clear H
         | [H: _ = _ |- _] => rewrite <-H in *; simpl in *; clear H
         end;
     kinv_simpl; auto).

Ltac kinv_magic_with tac :=
  repeat
    (try tac;
     repeat (* reductions *)
       (kinv_red;
        try
          match goal with
          | [H: SemAction _ _ _ _ _ |- _] => invertActionRep
          | [ |- exists _, _ /\ _ ] => kregmap_red; eexists; split
          | [ |- Substep _ _ _ _ _ ] => econstructor
          | [ |- In _ _ ] => simpl; tauto
          | [ |- SemAction _ _ _ _ _ ] => econstructor
          end);
     try reflexivity; (* same after reduction? *)
     repeat
       match goal with (* need some equality tactics? *)
       | [ |- ?m1 = ?m2 ] =>
         match type of m1 with
         | M.t _ => meqReify
         | forall _: BoundedIndexFull _, _ => boundedMapTac
         | _ => idtac
         end
       end;
     try (kinv_finish; fail)). (* need element equalities? *)

Ltac kinv_magic := kinv_magic_with idtac.

Ltac kduplicated := apply duplicate_traceRefines; auto.

Ltac kgetv k v m t f :=
  destruct (M.find k m) as [[[kind|] v]|]; [|exact f|exact f];
  destruct (decKind kind t); [subst|exact f].

(* TODO: "v" is not working *)
Ltac kexistv k v m t :=
  refine (exists v: fullType type (SyntaxKind t),
             M.find k m = Some (existT _ _ v) /\ _).

Hint Extern 1 (Specializable _) => vm_compute; reflexivity.
Hint Extern 1 (ValidRegsModules _ _) => kvalid_regs.
Hint Extern 1 (SubList (getExtMeths _) (getExtMeths _)) => vm_compute; tauto.
Hint Extern 1 (_ (initRegs _) = initRegs _) => kdecompose_regmap_init.
