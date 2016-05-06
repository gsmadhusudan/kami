Require Import Bool String List Program.Equality Program.Basics.
Require Import FunctionalExtensionality Classes.Morphisms.
Require Import Lib.CommonTactics Lib.FMap Lib.Struct Lib.StringEq.
Require Import Syntax Semantics Equiv StaticDynamic.

Set Implicit Arguments.

Ltac specializeAll k :=
  repeat
    match goal with
    | [H: forall _, _ |- _] => specialize (H k)
    end.

Section MapSet.
  Variable A: Type.
  Variable p: M.key -> A -> option A.

  Lemma transpose_neqkey_rmModify:
    M.F.P.transpose_neqkey eq (rmModify p).
  Proof.
    unfold M.F.P.transpose_neqkey; intros.
    unfold rmModify.
    destruct (p k e), (p k' e'); intuition.
  Qed.

  Theorem liftToMap1Empty: liftToMap1 p (M.empty _) = M.empty _.
  Proof.
    unfold liftToMap1, M.fold; reflexivity.
  Qed.

  Theorem liftToMap1MapsTo:
    forall m k v, M.MapsTo k v (liftToMap1 p m) <->
                  exists v', p k v' = Some v /\ M.MapsTo k v' m.
  Proof.
    intros m; M.mind m.
    - constructor; intros.
      + apply M.F.P.F.empty_mapsto_iff in H; intuition.
      + dest; subst.
        apply M.F.P.F.empty_mapsto_iff in H0; intuition.
    - constructor; intros.
      unfold liftToMap1 in H1.
      rewrite (M.F.P.fold_add (eqA := eq)) in H1; try apply transpose_neqkey_rmModify; intuition.
      fold (liftToMap1 p m) in H1.
      unfold rmModify in H1.
      case_eq (p k v); intros; subst.
      rewrite H2 in H1.
      + apply M.F.P.F.add_mapsto_iff in H1; dest.
        destruct H1; dest; subst.
        * exists v; intuition.
          apply M.F.P.F.add_mapsto_iff; intuition.
        * destruct (H k0 v0); dest; subst.
          specialize (H4 H3); dest; subst.
          exists x.
          intuition.
          apply M.F.P.F.add_mapsto_iff; intuition.
      + rewrite H2 in H1.
        destruct (H k0 v0); dest; subst.
        specialize (H3 H1); dest; subst.
        exists x.
        intuition.
        apply M.F.P.F.add_mapsto_iff; right; intuition.
        subst.
        apply M.MapsToIn1 in H5.
        intuition.
      + dest; subst.
        apply M.F.P.F.add_mapsto_iff in H2; dest.
        destruct H2; dest; try subst.
        * unfold liftToMap1.
          rewrite (M.F.P.fold_add (eqA := eq)); try apply transpose_neqkey_rmModify; intuition.
          unfold rmModify at 1.
          rewrite H1.
          apply M.F.P.F.add_mapsto_iff; intuition.
        * unfold liftToMap1.
          rewrite (M.F.P.fold_add (eqA := eq)); try apply transpose_neqkey_rmModify; intuition.
          unfold rmModify at 1.
          fold (liftToMap1 p m).
          specialize (H k0 v0).
          assert (sth: exists x, p k0 x = Some v0 /\ M.MapsTo k0 x m) by (eexists; eauto).
          apply H in sth.
          destruct (p k v); intuition.
          apply M.F.P.F.add_mapsto_iff; intuition.
  Qed.

  Lemma liftToMap1Subset s: M.DomainSubset (liftToMap1 p s) s.
  Proof.
    apply (M.map_induction (P := fun s => M.DomainSubset (liftToMap1 p s) s));
      unfold M.DomainSubset; intros.
    - rewrite liftToMap1Empty in *.
      intuition.
    - unfold liftToMap1 in H1.
      rewrite M.F.P.fold_add in H1; fold (liftToMap1 p m) in *; unfold rmModify.
      + apply M.F.P.F.add_in_iff.
        unfold rmModify in *.
        destruct (p k v).
        apply M.F.P.F.add_in_iff in H1.
        destruct H1; intuition.
        right; apply (H _ H1).
      + intuition.
      + clear; unfold Morphisms.Proper, Morphisms.respectful; intros; subst.
        apply M.leibniz in H1; subst.
        intuition.
      + clear; unfold M.F.P.transpose_neqkey; intros.
        unfold rmModify.
        destruct (p k e), (p k' e');
          try apply M.transpose_neqkey_Equal_add; intuition.
      + intuition.
  Qed.
        
  Theorem liftToMap1AddOne k v:
    liftToMap1 p (M.add k v (M.empty _)) =
    match p k v with
      | Some argRet => M.add k argRet (M.empty _)
      | None => M.empty _
    end.
  Proof.
    case_eq (p k v); unfold liftToMap1, rmModify, M.fold; simpl.
    intros a H.
    rewrite H; reflexivity.
    intros H.
    rewrite H; reflexivity.
  Qed.

End MapSet.

Lemma liftToMap1_find:
  forall {A} vp (m: M.t A) k,
    M.find k (liftToMap1 vp m) = match M.find k m with
                                 | Some v => vp k v
                                 | None => None
                                 end.
Proof.
  intros.
  case_eq (M.find k (liftToMap1 vp m)); intros.
  - apply M.Facts.P.F.find_mapsto_iff in H.
    apply liftToMap1MapsTo in H; dest; subst.
    apply M.F.P.F.find_mapsto_iff in H0.
    rewrite H0; auto.
  - apply M.F.P.F.not_find_in_iff in H.
    case_eq (M.find k m); intros; auto.
    apply M.Facts.P.F.find_mapsto_iff in H0.
    case_eq (vp k a); intros; auto.
    assert (exists v', vp k v' = Some a0 /\ M.MapsTo k v' m).
    { eexists; eauto. }
    apply liftToMap1MapsTo in H2.
    elim H. 
    eapply M.MapsToIn1; eauto.
Qed.

Ltac liftToMap1_find_tac :=
  repeat
    match goal with
    | [H: context [M.find _ (liftToMap1 _ _)] |- _] =>
      rewrite liftToMap1_find in H
    | [ |- context [M.find _ (liftToMap1 _ _)] ] =>
      rewrite liftToMap1_find
    end.

Lemma liftToMap1_union:
  forall {A} vp (m1 m2: M.t A),
    M.Disj m1 m2 ->
    liftToMap1 vp (M.union m1 m2) = M.union (liftToMap1 vp m1) (liftToMap1 vp m2).
Proof.
  intros; M.ext y.
  findeq.
  findeq_custom liftToMap1_find_tac.
  - exfalso; eapply M.Disj_find_union_3; eauto.
  - destruct (vp y a); auto.
Qed.

Lemma liftToMap1_subtractKV_1:
  forall {A} (deceqA: forall x y : A, sumbool (x = y) (x <> y)) vp (m1 m2: M.t A),
    M.Disj m1 m2 ->
    M.subtractKV deceqA (liftToMap1 vp m1) (liftToMap1 vp m2) =
    liftToMap1 vp (M.subtractKV deceqA m1 m2).
Proof.
  intros; M.ext y.
  findeq.
  findeq_custom liftToMap1_find_tac.
  - exfalso; eapply M.Disj_find_union_3; eauto.
  - destruct (vp y a); auto.
Qed.

Lemma liftToMap1_subtractKV_2:
  forall {A} (deceqA: forall x y : A, sumbool (x = y) (x <> y)) vp (m1 m2: M.t A),
    (forall k v1 v2, M.find k m1 = Some v1 -> M.find k m2 = Some v2 -> v1 = v2) ->
    M.subtractKV deceqA (liftToMap1 vp m1) (liftToMap1 vp m2) =
    liftToMap1 vp (M.subtractKV deceqA m1 m2).
Proof.
  intros; M.ext y.
  findeq.
  findeq_custom liftToMap1_find_tac.
  - specialize (H _ _ _ (eq_sym Heqv) (eq_sym Heqv0)); subst.
    destruct (vp y a0).
    + destruct (deceqA a a); [|elim f; reflexivity].
      destruct (deceqA a0 a0); [|elim f; reflexivity]; auto.
    + destruct (deceqA a0 a0); [|elim f; reflexivity]; auto.
  - destruct (vp y a); auto.
Qed.

Lemma liftToMap1IdElementwiseAdd A m:
  forall k (v: A),
    liftToMap1 (@idElementwise _) (M.add k v m) =
    rmModify (@idElementwise _) k v (liftToMap1 (@idElementwise _) m).
Proof.
  intros; remember (M.find k m) as okm. destruct okm.
  - apply eq_sym, M.find_add_3 in Heqokm.
    destruct Heqokm as [sm [? ?]]; subst.
    rewrite M.add_idempotent.
    unfold liftToMap1.
    rewrite M.F.P.fold_add; auto.
    rewrite M.F.P.fold_add; auto.
    unfold rmModify; simpl in *.
    rewrite M.add_idempotent; reflexivity.
    + apply M.transpose_neqkey_eq_add; intuition.
    + apply M.transpose_neqkey_eq_add; intuition.
  - unfold liftToMap1, rmModify; simpl in *.
    rewrite M.F.P.fold_add; auto.
    apply M.F.P.F.not_find_in_iff; auto.
Qed.

Lemma liftToMap1IdElementwiseId A m:
  liftToMap1 (@idElementwise A) m = m.
Proof.
  M.mind m; simpl in *.
  - rewrite liftToMap1Empty; reflexivity.
  - rewrite liftToMap1IdElementwiseAdd.
    unfold rmModify; simpl in *.
    rewrite H.
    reflexivity.
Qed.

Lemma idElementwiseId A: liftToMap1 (@idElementwise A) = id.
Proof.
  apply functional_extensionality; intros.
  apply liftToMap1IdElementwiseId.
Qed.

Lemma wellHidden_split:
  forall ma mb la lb,
    wellHidden (ConcatMod ma mb) (hide (mergeLabel la lb)) ->
    DisjList (getDefs ma) (getDefs mb) ->
    DisjList (getCalls ma) (getCalls mb) ->
    M.KeysSubset (calls la) (getCalls ma) ->
    M.KeysSubset (calls lb) (getCalls mb) ->
    M.KeysSubset (defs la) (getDefs ma) ->
    M.KeysSubset (defs lb) (getDefs mb) ->
    wellHidden ma (hide la) /\ wellHidden mb (hide lb).
Proof.
  intros.

  assert (M.Disj (defs la) (defs lb))
    by (eapply M.DisjList_KeysSubset_Disj with (d1:= getDefs ma); eauto).
  assert (M.Disj (calls la) (calls lb))
    by (eapply M.DisjList_KeysSubset_Disj with (d1:= getCalls ma); eauto).
  
  unfold wellHidden in *; dest.
  destruct la as [anna dsa csa], lb as [annb dsb csb].
  simpl in *; split; dest.

  - split.
    + clear H8.
      unfold M.KeysDisj, M.KeysSubset in *; intros.
      specializeAll k.
      specialize (H (getCalls_in_1 ma mb _ H8)).
      rewrite M.F.P.F.in_find_iff in *.
      intro Hx; elim H; clear H.
      findeq.
      specialize (H1 k); destruct H1; auto.
    + clear H.
      unfold M.KeysDisj, M.KeysSubset in *; intros.
      specializeAll k.
      specialize (H8 (getDefs_in_1 ma mb _ H)).
      rewrite M.F.P.F.in_find_iff in *.
      intro Hx; elim H8; clear H8.
      findeq.
      specialize (H0 k); destruct H0; auto.

  - split.
    + clear H8.
      unfold M.KeysDisj, M.KeysSubset in *; intros.
      specializeAll k.
      specialize (H (getCalls_in_2 ma mb _ H8)).
      rewrite M.F.P.F.in_find_iff in *.
      intro Hx; elim H; clear H.
      findeq;
        try (remember (M.find k dsb) as v; destruct v;
             remember (M.find k csb) as v; destruct v; findeq).
      specialize (H1 k); destruct H1; auto.
    + clear H.
      unfold M.KeysDisj, M.KeysSubset in *; intros.
      specializeAll k.
      specialize (H8 (getDefs_in_2 ma mb _ H)).
      rewrite M.F.P.F.in_find_iff in *.
      intro Hx; elim H8; clear H8.
      findeq;
        try (remember (M.find k csb) as v; destruct v;
             remember (M.find k dsb) as v; destruct v; findeq).
      specialize (H0 k); destruct H0; auto.
Qed.

Lemma hide_mergeLabel_idempotent:
  forall la lb,
    M.Disj (defs la) (defs lb) ->
    M.Disj (calls la) (calls lb) ->
    hide (mergeLabel la lb) = hide (mergeLabel (hide la) (hide lb)).
Proof.
  intros; destruct la as [anna dsa csa], lb as [annb dsb csb].
  simpl in *.
  unfold hide; simpl; f_equal; meq.
Qed.

Lemma wellHidden_combine:
  forall m la lb,
    wellHidden m la ->
    wellHidden m lb ->
    wellHidden m (mergeLabel la lb).
Proof.
  intros.
  destruct la as [anna dsa csa], lb as [annb dsb csb].
  unfold wellHidden in *; simpl in *; dest.
  split; unfold M.KeysDisj in *; intros.
  - specialize (H k H3); specialize (H0 k H3); findeq.
  - specialize (H2 k H3); specialize (H1 k H3); findeq.
Qed.

Lemma wellHidden_mergeLabel_hide:
  forall m la lb,
    wellHidden m (hide la) ->
    wellHidden m (hide lb) ->
    M.KeysSubset (defs la) (getDefs m) ->
    M.KeysSubset (calls la) (getCalls m) ->
    M.KeysSubset (defs lb) (getDefs m) ->
    M.KeysSubset (calls lb) (getCalls m) ->
    mergeLabel (hide la) (hide lb) = hide (mergeLabel la lb).
Proof.
  intros; destruct la as [anna dsa csa], lb as [annb dsb csb].
  unfold hide, wellHidden in *; simpl in *; dest.
  unfold M.KeysDisj, M.KeysSubset in *.
  f_equal.

  - meq; repeat
           match goal with
           | [H: forall _, _ |- _] => specialize (H y)
           end.
    + elim H0; [apply H4; findeq|findeq].
    + elim H0; [apply H2; findeq|findeq].
    + elim H; [apply H4; findeq|findeq].
    + elim H6; [apply H3; findeq|findeq].
    + elim H6; [apply H3; findeq|findeq].
    + elim H6; [apply H3; findeq|findeq].

  - meq; repeat
           match goal with
           | [H: forall _, _ |- _] => specialize (H y)
           end.
    + elim H0; [apply H4; findeq|findeq].
    + elim H5; [apply H1; findeq|findeq].
    + elim H6; [apply H3; findeq|findeq].
    + elim H; [apply H4; findeq|findeq].
    + elim H; [apply H4; findeq|findeq].
    + elim H; [apply H4; findeq|findeq].
Qed.

Lemma canCombine_CanCombineUL:
  forall m o u1 u2 ul1 ul2 cs1 cs2
         (Hss1: Substep m o u1 ul1 cs1)
         (Hss2: Substep m o u2 ul2 cs2),
    canCombine {| substep := Hss1 |} {| substep := Hss2 |} <->
    CanCombineUL u1 u2 (getLabel ul1 cs1) (getLabel ul2 cs2).
Proof.
  unfold canCombine, CanCombineUL, CanCombineLabel; simpl; intros; split; intros; dest.
  - repeat split; auto.
    + destruct ul1 as [[r1|]|[[dmn1 dmb1]|]], ul2 as [[r2|]|[[dmn2 dmb2]|]]; auto.
      specialize (H0 _ _ eq_refl eq_refl); simpl in H0.
      auto.
    + destruct ul1 as [[r1|]|[[dmn1 dmb1]|]], ul2 as [[r2|]|[[dmn2 dmb2]|]]; auto;
        try (destruct H1; discriminate; fail).
  - repeat split; auto.
    + intros; destruct ul1 as [[r1|]|[[dmn1 dmb1]|]], ul2 as [[r2|]|[[dmn2 dmb2]|]];
        try discriminate.
      inv H3; inv H4; simpl.
      intro Hx; subst.
      specialize (H0 dmn2); destruct H0; findeq.
    + intros; destruct ul1 as [[r1|]|[[dmn1 dmb1]|]], ul2 as [[r2|]|[[dmn2 dmb2]|]];
        eexists; intuition idtac.

      Grab Existential Variables.
      exact None.
      exact None.
      exact None.
      exact None.
Qed.
   
Lemma CanCombineLabel_hide:
  forall la lb,
    CanCombineLabel la lb ->
    CanCombineLabel (hide la) (hide lb).
Proof.
  intros; destruct la as [anna dsa csa], lb as [annb dsb csb].
  inv H; simpl in *; dest.
  repeat split; unfold hide; simpl in *; auto.
  - apply M.Disj_Sub with (m2:= dsa); [|apply M.subtractKV_sub].
    apply M.Disj_comm.
    apply M.Disj_Sub with (m2:= dsb); [|apply M.subtractKV_sub].
    auto.
  - apply M.Disj_Sub with (m2:= csa); [|apply M.subtractKV_sub].
    apply M.Disj_comm.
    apply M.Disj_Sub with (m2:= csb); [|apply M.subtractKV_sub].
    auto.
Qed.

Lemma equivalentLabelSeq_length:
  forall p lsa lsb,
    equivalentLabelSeq p lsa lsb ->
    List.length lsa = List.length lsb.
Proof. induction lsa; intros; inv H; simpl; auto. Qed.

Lemma equivalentLabelSeq_CanCombineLabelSeq:
  forall p (Hp: Proper (equivalentLabel p ==> equivalentLabel p ==> impl) CanCombineLabel)
         lsa lsb lsc lsd,
    equivalentLabelSeq p lsa lsb ->
    equivalentLabelSeq p lsc lsd ->
    CanCombineLabelSeq lsa lsc ->
    CanCombineLabelSeq lsb lsd.
Proof.
  ind lsa.
  - destruct lsc; intuition idtac.
    inv H; inv H0; constructor.
  - destruct lsc; intuition idtac.
    inv H; inv H0; constructor; [|eapply IHlsa; eauto].
    eapply Hp; eauto.
Qed.

Lemma hide_idempotent:
  forall (l: LabelT), hide l = hide (hide l).
Proof.
  intros; destruct l as [ann ds cs].
  unfold hide; simpl; f_equal;
  apply M.subtractKV_idempotent.
Qed.

Lemma step_hide:
  forall m o u l,
    Step m o u l -> hide l = l.
Proof.
  intros; apply step_consistent in H; inv H.
  rewrite <-hide_idempotent; auto.
Qed.

Inductive HiddenLabelSeq: LabelSeqT -> Prop :=
| HLSNil: HiddenLabelSeq nil
| HLSCons:
    forall l ll,
      HiddenLabelSeq ll ->
      hide l = l ->
      HiddenLabelSeq (l :: ll).

Lemma behavior_hide:
  forall m n ll,
    Behavior m n ll -> HiddenLabelSeq ll.
Proof.
  intros; inv H.
  induction HMultistepBeh; [constructor|].
  constructor; auto.
  eapply step_hide; eauto.
Qed.

Section EmptyDefs.
  Variable m: Modules.
  Variable o: RegsT.
  Variable defsZero: getDefsBodies m = nil.
  
  Theorem substepsIndZero u l:
    SubstepsInd m o u l ->
    defs l = M.empty _ /\
    Substep m o u match annot l with
                    | None => Meth None
                    | Some r => Rle r
                  end (calls l).
  Proof.
    intros si.
    dependent induction si.
    - constructor; econstructor; eauto.
    - dest; destruct l; subst.
      inv H; simpl in *; repeat rewrite M.union_empty_L; constructor; auto;
      repeat rewrite M.union_empty_R; unfold CanCombineUUL in *; simpl in *; dest.
      + destruct annot; intuition.
        inversion H4.
        econstructor; eauto.
      + destruct annot; auto.
      + destruct annot.
        * intuition.
        * inversion H4.
          rewrite M.union_empty_L, M.union_empty_R.
          econstructor; eauto.
      + rewrite defsZero in *.
        intuition.
      + rewrite defsZero in *.
        intuition.
  Qed.

  Theorem substepsIndZeroHide u l:
    SubstepsInd m o u l ->
    hide l = l.
  Proof.
    intros si.
    apply substepsIndZero in si; dest.
    unfold hide; destruct l; simpl in *; subst.
    rewrite M.subtractKV_empty_1.
    rewrite M.subtractKV_empty_2.
    reflexivity.
  Qed.

  Theorem stepZero u l:
    Step m o u l ->
    defs l = M.empty _ /\
    Substep m o u match annot l with
                    | None => Meth None
                    | Some r => Rle r
                  end (calls l).
  Proof.
    intros si.
    apply step_consistent in si.
    inv si.
    apply substepsIndZero.
    rewrite substepsIndZeroHide with (u := u); auto.
  Qed.

  Theorem substepZero_imp_step u a cs:
    Substep m o u a cs ->
    Step m o u (getLabel a cs).
  Proof.
    intros si.
    assert (sth: substepsComb ({| substep := si |} :: nil)).
    { constructor 2.
      constructor.
      intuition.
    }
    pose proof (StepIntro sth); simpl in *.
    unfold addLabelLeft in H;
      unfold getSLabel in H.
    assert (ua: unitAnnot
                  {| upd := u; unitAnnot := a; cms := cs; substep := si |} = a) by reflexivity.
    rewrite ua in H.
    assert (ub: cms
                  {| upd := u; unitAnnot := a; cms := cs; substep := si |} = cs) by reflexivity.
    rewrite ub in H.
    clear ua ub.
    assert (st: mergeLabel (getLabel a cs) {| annot := None;
                                          defs := M.empty _;
                                          calls := M.empty _ |} = getLabel a cs).
    { simpl.
      destruct a.
      - repeat rewrite M.union_empty_L, M.union_empty_R.
        reflexivity.
      - destruct o0;
        try destruct a; repeat rewrite M.union_empty_L; repeat rewrite M.union_empty_R;
        try reflexivity.
    }
    rewrite st in H; clear st.
    rewrite M.union_empty_L in H.
    assert (s: hide (getLabel a cs) = getLabel a cs).
    { clear H sth.
      unfold hide.
      simpl.
      destruct a; destruct o0; try destruct a; repeat rewrite M.subtractKV_empty_1;
      repeat rewrite M.subtractKV_empty_2; try reflexivity.
      inv si.
      rewrite defsZero in HIn.
      intuition.
    }
    rewrite s in *; clear s.
    assert (t: wellHidden m (getLabel a cs)).
    { clear sth H.
      unfold wellHidden.
      simpl in *.
      unfold getDefs.
      rewrite defsZero.
      simpl in *.
      destruct a;
      constructor;
      destruct o0; try destruct a;
      try apply M.KeysDisj_empty; try apply M.KeysDisj_nil.
      inversion si.
      rewrite defsZero in HIn.
      intuition.
    }
    apply H; intuition.
  Qed.

End EmptyDefs.

Lemma DisjList_string_cons:
  forall l1 l2 (e: string),
    ~ In e l2 -> DisjList l1 l2 -> DisjList (e :: l1) l2.
Proof.
  unfold DisjList; intros.
  destruct (string_dec e e0); subst; auto.
  pose proof (H0 e0); clear H0.
  inv H1; auto.
  left; intro Hx; inv Hx; auto.
Qed.

Lemma isLeaf_implies_disj:
  forall {retK} (a: ActionT typeUT retK) calls,
    true = isLeaf a calls -> DisjList (getCallsA a) calls.
Proof.
  induction a; simpl; intros; auto.
  - apply eq_sym, andb_true_iff in H0; dest.
    remember (string_in _ _) as sin; destruct sin; [inv H0|].
    apply string_in_dec_not_in in Heqsin.
    apply DisjList_string_cons; auto.
  - apply eq_sym, andb_true_iff in H0; dest.
    apply andb_true_iff in H0; dest.
    apply DisjList_app_4; auto.
    apply DisjList_app_4; auto.
  - apply DisjList_nil_1.
Qed.

Lemma noCallsRules_implies_disj:
  forall calls rules,
    noCallsRules rules calls = true ->
    DisjList (getCallsR rules) calls.
Proof.
  induction rules; simpl; intros; [apply DisjList_nil_1|].
  remember (isLeaf (attrType a typeUT) calls) as blf; destruct blf; [|discriminate].
  apply DisjList_app_4.
  - apply isLeaf_implies_disj; auto.
  - apply IHrules; auto.
Qed.

Lemma noCallsDms_implies_disj:
  forall calls dms,
    noCallsDms dms calls = true ->
    DisjList (getCallsM dms) calls.
Proof.
  induction dms; simpl; intros; [apply DisjList_nil_1|].
  remember (isLeaf (projT2 (attrType a) typeUT tt) calls) as blf; destruct blf; [|discriminate].
  apply DisjList_app_4.
  - apply isLeaf_implies_disj; auto.
  - apply IHdms; auto.
Qed.

Lemma noInternalCalls_implies_disj:
  forall m,
    noInternalCalls m = true ->
    DisjList (getCalls m) (getDefs m).
Proof.
  unfold noInternalCalls, noCalls, getCalls, getDefs; simpl; intros.
  apply andb_true_iff in H; dest.
  apply DisjList_app_4.
  - apply noCallsRules_implies_disj; auto.
  - apply noCallsDms_implies_disj; auto.
Qed.

Section ModEquiv.
  Variable m: Modules.
  Variable mEquiv: ModEquiv type typeUT m.

  Lemma getCallsARulesSubset (a: Action Void) rName:
    forall x,
      In x (getCallsA (a typeUT)) ->
      In (rName :: a)%struct (getRules m) ->
      In x (getCalls m).
  Proof.
    intros.
    unfold getCalls.
    apply in_or_app.
    left.
    induction (getRules m).
    - intuition.
    - simpl in *.
      destruct H0; subst; apply in_or_app; intuition.
  Qed.

  Lemma getCallsAMethsSubset (a: sigT MethodT) mName:
    forall x,
      In x (getCallsA (projT2 a typeUT tt)) ->
      In (mName :: a)%struct (getDefsBodies m) ->
      In x (getCalls m).
  Proof.
    intros.
    unfold getCalls.
    apply in_or_app.
    right.
    induction (getDefsBodies m).
    - intuition.
    - simpl in *.
      destruct H0; subst; apply in_or_app; intuition.
  Qed.

  Theorem staticDynCallsSubstep o u rm cs:
    Substep m o u rm cs ->
    forall f, M.In f cs -> In f (getCalls m).
  Proof.
    dependent induction rm; dependent induction o0; intros.
    - eapply callsSubsetR in H; dest; subst;
        try eapply getCallsARulesSubset in H1; eauto.
    - dependent destruction H.
      apply M.F.P.F.empty_in_iff in H0; intuition.
    - destruct a.
      eapply callsSubsetM  in H; dest; subst;
        try eapply getCallsAMethsSubset in H1; eauto.
    - dependent destruction H.
      apply M.F.P.F.empty_in_iff in H0; intuition.
  Qed.

  Theorem staticDynCallsSubsteps o ss:
    forall f, M.In f (calls (foldSSLabel (m := m) (o := o) ss)) -> In f (getCalls m).
  Proof.
    intros.
    induction ss; simpl in *.
    - exfalso.
      apply (proj1 (M.F.P.F.empty_in_iff _ _) H).
    - unfold addLabelLeft, mergeLabel in *.
      destruct a.
      simpl in *.
      destruct unitAnnot.
      + destruct (foldSSLabel ss); simpl in *.
        pose proof (M.union_In H) as sth.
        destruct sth.
        * apply (staticDynCallsSubstep substep); intuition.
        * intuition.
      + destruct (foldSSLabel ss); simpl in *.
        dependent destruction o0; simpl in *.
        * dependent destruction a; simpl in *.
          pose proof (M.union_In H) as sth.
          { destruct sth.
            - apply (staticDynCallsSubstep substep); intuition.
            - intuition.
          }
        * pose proof (M.union_In H) as sth.
          { destruct sth.
            - apply (staticDynCallsSubstep substep); intuition.
            - intuition.
          }
  Qed.
End ModEquiv.

Theorem staticDynDefsSubstep m o u far cs:
  Substep m o u (Meth (Some far)) cs ->
  List.In (attrName far) (getDefs m).
Proof.
  intros.
  dependent induction H; simpl in *.
  unfold getDefs in *.
  clear - HIn.
  induction (getDefsBodies m).
  - intuition.
  - simpl in *.
    destruct HIn.
    + subst.
      left; intuition.
    + right; intuition.
Qed.

Theorem staticDynDefsSubstepsInd m o u l:
  SubstepsInd m o u l ->
  forall x, M.In x (defs l) -> List.In x (getDefs m).
Proof.
  intros.
  dependent induction H; simpl in *.
  - apply M.F.P.F.empty_in_iff in H0; intuition.
  - destruct sul.
    destruct l.
    destruct annot; simpl in *; subst; simpl in *;
    rewrite M.union_empty_L in H4; simpl in *; apply IHSubstepsInd; intuition.
    destruct l.
    destruct o0.
    + destruct a.
      destruct ll.
      simpl in *.
      inv H3.
      apply M.union_In in H4.
      destruct H4.
      * apply M.F.P.F.add_in_iff in H2.
        { destruct H2; subst.
          - apply staticDynDefsSubstep in H0.
            assumption.
          - apply M.F.P.F.empty_in_iff in H2; intuition.
        }
      * apply IHSubstepsInd; intuition.
    + destruct ll.
      simpl in *.
      rewrite M.union_empty_L in H3.
      inv H3.
      apply IHSubstepsInd; intuition.
Qed.

Theorem staticDynDefsSubsteps m o ss:
  forall f, M.In f (defs (foldSSLabel (m := m) (o := o) ss)) -> In f (getDefs m).
Proof.
  intros.
  induction ss; simpl in *.
  - exfalso.
    apply (proj1 (M.F.P.F.empty_in_iff _ _) H).
  - unfold addLabelLeft, mergeLabel in *.
    destruct a.
    simpl in *.
    destruct unitAnnot.
    + destruct (foldSSLabel ss); simpl in *.
      rewrite M.union_empty_L in H.
      intuition.
    + destruct (foldSSLabel ss); simpl in *.
      dependent destruction o0; simpl in *.
      * dependent destruction a; simpl in *.
        pose proof (M.union_In H) as sth.
        { destruct sth.
          - apply M.F.P.F.add_in_iff in H0.
            destruct H0.
            + subst.
              apply (staticDynDefsSubstep substep).
            + exfalso; apply ((proj1 (M.F.P.F.empty_in_iff _ _)) H0).
          - intuition.
        }
      * rewrite M.union_empty_L in H.
        intuition.
Qed.

Lemma mergeLabel_assoc:
  forall l1 l2 l3,
    mergeLabel (mergeLabel l1 l2) l3 = mergeLabel l1 (mergeLabel l2 l3).
Proof.
  intros; destruct l1 as [[[|]|] ? ?], l2 as [[[|]|] ? ?], l3 as [[[|]|] ? ?];
    unfold mergeLabel; try reflexivity; try (f_equal; auto).
Qed.

Lemma substepsInd_defs_in:
  forall m or u l,
    SubstepsInd m or u l -> M.KeysSubset (defs l) (getDefs m).
Proof.
  induction 1; simpl; [apply M.KeysSubset_empty|].
  subst; destruct l as [ann ds cs]; simpl in *.
  apply M.KeysSubset_union; auto.
  destruct sul as [|[[dmn dmv]|]]; try (apply M.KeysSubset_empty).
  apply M.KeysSubset_add; [apply M.KeysSubset_empty|].
  pose proof (staticDynDefsSubstep H0); auto.
Qed.

Lemma substepsInd_calls_in:
  forall m (Hequiv: ModEquiv type typeUT m) or u l,
    SubstepsInd m or u l -> M.KeysSubset (calls l) (getCalls m).
Proof.
  induction 2; simpl; [apply M.KeysSubset_empty|].
  subst; destruct l as [ann ds cs]; simpl in *.
  apply M.KeysSubset_union; auto.
  pose proof (staticDynCallsSubstep Hequiv H0); auto.
Qed.

Lemma step_defs_in:
  forall m (Hequiv: ModEquiv type typeUT m) or u l,
    Step m or u l -> M.KeysSubset (defs l) (getDefs m).
Proof.
  intros; apply step_consistent in H; inv H.
  apply substepsInd_defs_in in HSubSteps; auto.
  destruct l0 as [ann ds cs]; unfold hide in *; simpl in *.
  eapply M.KeysSubset_Sub; eauto.
  apply M.subtractKV_sub.
Qed.

Lemma step_calls_in:
  forall m (Hequiv: ModEquiv type typeUT m) or u l,
    Step m or u l -> M.KeysSubset (calls l) (getCalls m).
Proof.
  intros; apply step_consistent in H; inv H.
  apply substepsInd_calls_in in HSubSteps; auto.
  destruct l0 as [ann ds cs]; unfold hide in *; simpl in *.
  eapply M.KeysSubset_Sub; eauto.
  apply M.subtractKV_sub.
Qed.

Lemma multistep_defs_in:
  forall m (Hequiv: ModEquiv type typeUT m) or ll u,
    Multistep m or u ll -> Forall (fun l => M.KeysSubset (defs l) (getDefs m)) ll.
Proof.
  induction ll; intros; auto.
  inv H; constructor; eauto.
  eapply step_defs_in; eauto.
Qed.

Lemma multistep_calls_in:
  forall m (Hequiv: ModEquiv type typeUT m) or ll u,
    Multistep m or u ll -> Forall (fun l => M.KeysSubset (calls l) (getCalls m)) ll.
Proof.
  induction ll; intros; auto.
  inv H; constructor; eauto.
  eapply step_calls_in; eauto.
Qed.

Lemma behavior_defs_in:
  forall m (Hequiv: ModEquiv type typeUT m) ll u,
    Behavior m u ll -> Forall (fun l => M.KeysSubset (defs l) (getDefs m)) ll.
Proof.
  intros; inv H.
  eapply multistep_defs_in; eauto.
Qed.

Lemma behavior_calls_in:
  forall m (Hequiv: ModEquiv type typeUT m) ll u,
    Behavior m u ll -> Forall (fun l => M.KeysSubset (calls l) (getCalls m)) ll.
Proof.
  intros; inv H.
  eapply multistep_calls_in; eauto.
Qed.
      
Lemma step_defs_disj:
  forall m or u l,
    Step m or u l -> M.KeysDisj (defs l) (getCalls m).
Proof.
  intros; apply step_consistent in H.
  inv H; destruct l0 as [ann ds cs].
  unfold wellHidden, hide in *; simpl in *; dest; auto.
Qed.

Lemma step_calls_disj:
  forall m or u l,
    Step m or u l -> M.KeysDisj (calls l) (getDefs m).
Proof.
  intros; apply step_consistent in H.
  inv H; destruct l0 as [ann ds cs].
  unfold wellHidden, hide in *; simpl in *; dest; auto.
Qed.

Lemma multistep_defs_disj:
  forall m or ll u,
    Multistep m or u ll ->
    Forall (fun l => M.KeysDisj (defs l) (getCalls m)) ll.
Proof.
  induction ll; intros; auto.
  inv H; constructor.
  - eapply step_defs_disj; eauto.
  - eapply IHll; eauto.
Qed.

Lemma multistep_calls_disj:
  forall m or ll u,
    Multistep m or u ll ->
    Forall (fun l => M.KeysDisj (calls l) (getDefs m)) ll.
Proof.
  induction ll; intros; auto.
  inv H; constructor.
  - eapply step_calls_disj; eauto.
  - eapply IHll; eauto.
Qed.

Lemma behavior_defs_disj:
  forall m ll n,
    Behavior m n ll ->
    Forall (fun l => M.KeysDisj (defs l) (getCalls m)) ll.
Proof.
  induction ll; intros; auto.
  inv H; inv HMultistepBeh; constructor.
  - eapply step_defs_disj; eauto.
  - eapply IHll.
    econstructor; eauto.
Qed.

Lemma behavior_calls_disj:
  forall m ll n,
    Behavior m n ll ->
    Forall (fun l => M.KeysDisj (calls l) (getDefs m)) ll.
Proof.
  induction ll; intros; auto.
  inv H; inv HMultistepBeh; constructor.
  - eapply step_calls_disj; eauto.
  - eapply IHll.
    econstructor; eauto.
Qed.

Lemma step_defs_extDefs_in:
  forall m (Hequiv: ModEquiv type typeUT m) o u l,
    Step m o u l ->
    M.KeysSubset (defs l) (getExtDefs m).
Proof.
  intros.
  pose proof (step_defs_in Hequiv H).
  pose proof (step_defs_disj H).

  unfold M.KeysSubset, M.KeysDisj in *; intros.
  specialize (H0 k H2).
  specialize (H1 k).
  destruct (in_dec string_dec k (getCalls m)); intuition idtac.
  apply filter_In; split; auto.
  apply negb_true_iff.
  remember (string_in k (getCalls m)) as kin; destruct kin; auto.
  apply string_in_dec_in in Heqkin; elim n; auto.
Qed.

Lemma step_defs_ext_in:
  forall m (Hequiv: ModEquiv type typeUT m) o u l,
    Step m o u l ->
    M.KeysSubset (defs l) (getExtMeths m).
Proof.
  intros.
  pose proof (step_defs_extDefs_in Hequiv H).
  eapply M.KeysSubset_SubList; eauto.
  apply SubList_app_1, SubList_refl.
Qed.

Lemma step_calls_extCalls_in:
  forall m (Hequiv: ModEquiv type typeUT m) o u l,
    Step m o u l ->
    M.KeysSubset (calls l) (getExtCalls m).
Proof.
  intros.
  pose proof (step_calls_in Hequiv H).
  pose proof (step_calls_disj H).

  unfold M.KeysSubset, M.KeysDisj in *; intros.
  specialize (H0 k H2).
  specialize (H1 k).
  destruct (in_dec string_dec k (getDefs m)); intuition idtac.
  apply filter_In; split; auto.
  apply negb_true_iff.
  remember (string_in k (getDefs m)) as kin; destruct kin; auto.
  apply string_in_dec_in in Heqkin; elim n; auto.
Qed.

Lemma step_calls_ext_in:
  forall m (Hequiv: ModEquiv type typeUT m) o u l,
    Step m o u l ->
    M.KeysSubset (calls l) (getExtMeths m).
Proof.
  intros.
  pose proof (step_calls_extCalls_in Hequiv H).
  eapply M.KeysSubset_SubList; eauto.
  apply SubList_app_2, SubList_refl.
Qed.

Lemma filterDms_getCalls:
  forall regs rules dms filt,
    SubList (getCalls (Mod regs rules (filterDms dms filt)))
            (getCalls (Mod regs rules dms)).
Proof.
  unfold getCalls; simpl; intros.
  apply SubList_app_3; [apply SubList_app_1, SubList_refl|].
  apply SubList_app_2.

  clear.
  induction dms; simpl; [apply SubList_nil|].
  destruct (string_in _ _).
  - apply SubList_app_2; auto.
  - apply SubList_app_3.
    + apply SubList_app_1, SubList_refl.
    + apply SubList_app_2; auto.
Qed.

Lemma filterDms_wellHidden:
  forall regs rules dms l,
    wellHidden (Mod regs rules dms) (hide l) ->
    forall filt,
      wellHidden (Mod regs rules (filterDms dms filt)) (hide l).
Proof.
  unfold wellHidden, hide; simpl; intros; dest.
  split.
  - eapply M.KeysDisj_SubList; eauto.
    apply filterDms_getCalls.
  - unfold getDefs in *; simpl in *.
    eapply M.KeysDisj_SubList; eauto.

    clear.
    induction dms; simpl; auto.
    + apply SubList_nil.
    + destruct (string_in _ _).
      * apply SubList_cons_right; auto.
      * simpl; apply SubList_cons; intuition.
        apply SubList_cons_right; auto.
Qed.

Lemma merge_preserves_substep:
  forall m or u ul cs,
    Substep m or u ul cs ->
    Substep (Mod (getRegInits m) (getRules m) (getDefsBodies m)) or u ul cs.
Proof. induction 1; simpl; intros; try (econstructor; eauto). Qed.

Lemma merge_preserves_substepsInd:
  forall m or u l,
    SubstepsInd m or u l ->
    SubstepsInd (Mod (getRegInits m) (getRules m) (getDefsBodies m)) or u l.
Proof.
  induction 1; intros; [constructor|].
  subst; eapply SubstepsCons; eauto.
  apply merge_preserves_substep; auto.
Qed.

Lemma merge_preserves_stepInd:
  forall m or nr l,
    StepInd m or nr l ->
    StepInd (Mod (getRegInits m) (getRules m) (getDefsBodies m)) or nr l.
Proof.
  intros; inv H.
  constructor; auto.
  apply merge_preserves_substepsInd; auto.
Qed.

Lemma merge_preserves_step:
  forall m or nr l,
    Step m or nr l ->
    Step (Mod (getRegInits m) (getRules m) (getDefsBodies m)) or nr l.
Proof.
  intros; apply step_consistent; apply step_consistent in H.
  apply merge_preserves_stepInd; auto.
Qed.

Lemma substep_dms_weakening:
  forall regs rules dms or u ul cs,
    Substep (Mod regs rules dms) or u ul cs ->
    forall filt,
      M.KeysDisj (defs (getLabel ul cs)) filt ->
      Substep (Mod regs rules (filterDms dms filt)) or u ul cs.
Proof.
  induction 1; simpl; intros; try (econstructor; eauto; fail).

  eapply SingleMeth; eauto; subst.
  clear -H HIn; simpl in *.
  specialize (H (attrName f)).
  apply filter_In.
  remember (string_in _ _) as sin; destruct sin; auto.
  apply string_in_dec_in in Heqsin.
  elim H; auto.
  apply M.F.P.F.add_in_iff; auto.
Qed.

Lemma substepInd_dms_weakening:
  forall regs rules dms or u l,
    SubstepsInd (Mod regs rules dms) or u l ->
    forall filt,
      M.KeysDisj (defs l) filt ->
      SubstepsInd (Mod regs rules (filterDms dms filt)) or u l.
Proof.
  induction 1; intros; subst; simpl; [constructor|].
  eapply SubstepsCons; eauto.
  - apply IHSubstepsInd.
    clear -H4.
    destruct (getLabel sul scs) as [ann ds cs], l as [lann lds lcs].
    simpl in *; eapply M.KeysDisj_union_2; eauto.
  - apply substep_dms_weakening; auto.
    clear -H4.
    destruct (getLabel sul scs) as [ann ds cs], l as [lann lds lcs].
    simpl in *; eapply M.KeysDisj_union_1; eauto.
Qed.

Lemma substepsInd_meths_disj:
  forall regs rules dms
    (mEquiv: ModEquiv type typeUT (Mod regs rules dms)),
    DisjList (getCalls (Mod regs rules dms)) (getDefs (Mod regs rules dms)) ->
    forall or u l,
      SubstepsInd (Mod regs rules dms) or u l ->
      M.Disj (calls l) (defs l).
Proof.
  intros.
  pose proof (substepsInd_calls_in mEquiv H0).
  pose proof (substepsInd_defs_in H0).
  eapply M.DisjList_KeysSubset_Disj; eauto.
Qed.

Lemma substepsInd_hide_void:
  forall regs rules dms
    (mEquiv: ModEquiv type typeUT (Mod regs rules dms)),
    DisjList (getCalls (Mod regs rules dms)) (getDefs (Mod regs rules dms)) ->
    forall or u l,
      SubstepsInd (Mod regs rules dms) or u l ->
      hide l = l.
Proof.
  intros; destruct l as [ann ds cs].
  pose proof (substepsInd_meths_disj mEquiv H H0).
  unfold hide; simpl in *; f_equal; apply M.subtractKV_disj_invalid; mdisj.
Qed.

Lemma stepInd_dms_weakening:
  forall regs rules dms or u l
         (mEquiv: ModEquiv type typeUT (Mod regs rules dms)),
    DisjList (getCalls (Mod regs rules dms)) (getDefs (Mod regs rules dms)) ->
    StepInd (Mod regs rules dms) or u l ->
    forall filt,
      M.KeysDisj (defs l) filt ->
      StepInd (Mod regs rules (filterDms dms filt)) or u l.
Proof.
  induction 3; intros.
  constructor.
  - erewrite substepsInd_hide_void in H0; eauto.
    apply substepInd_dms_weakening; auto.
  - apply filterDms_wellHidden; auto.
Qed.

Lemma step_dms_weakening:
  forall regs rules dms or u l,
    ModEquiv type typeUT (Mod regs rules dms) ->
    DisjList (getCalls (Mod regs rules dms))
             (getDefs (Mod regs rules dms)) ->
    Step (Mod regs rules dms) or u l ->
    forall filt,
      M.KeysDisj (defs l) filt ->
      Step (Mod regs rules (filterDms dms filt)) or u l.
Proof.
  intros; subst; simpl.
  apply step_consistent.
  apply step_consistent in H1.
  apply stepInd_dms_weakening; auto.
Qed.

Definition IsChild (c p: Modules) :=
  (exists c', p = ConcatMod c c' \/ p = ConcatMod c' c).
Hint Unfold IsChild.

Lemma substep_modules_weakening:
  forall mc o u ul cs,
    Substep mc o u ul cs ->
    forall mp,
      IsChild mc mp ->
      Substep mp o u ul cs.
Proof.
  induction 1; simpl; intros; subst; try (constructor; auto; fail).
  - eapply SingleRule; eauto.
    inv H; inv H0; apply in_or_app; auto.
  - eapply SingleMeth; eauto.
    inv H; inv H0; apply in_or_app; auto.
Qed.

Lemma substepsInd_modules_weakening:
  forall mc o u l,
    SubstepsInd mc o u l ->
    forall mp,
      IsChild mc mp ->
      SubstepsInd mp o u l.
Proof.
  induction 1; simpl; intros; subst; [constructor|].
  eapply SubstepsCons; eauto.
  eapply substep_modules_weakening; eauto.
Qed.

Lemma semAction_oldRegs_weakening:
  forall o {retK} retv (a: ActionT type retK) u cs,
    SemAction o a u cs retv ->
    forall so,
      M.Sub o so ->
      SemAction so a u cs retv.
Proof.
  induction 1; simpl; intros; subst.
  - econstructor; eauto.
  - econstructor; eauto.
  - econstructor; eauto.
  - econstructor; eauto.
  - eapply SemIfElseTrue; eauto.
  - eapply SemIfElseFalse; eauto.
  - econstructor; eauto.
  - econstructor; eauto.
Qed.

Lemma substep_oldRegs_weakening:
  forall m o u ul cs,
    Substep m o u ul cs ->
    forall so,
      M.Sub o so ->
      Substep m so u ul cs.
Proof.
  induction 1; simpl; intros; subst; try (constructor; auto; fail).
  - eapply SingleRule; eauto.
    eapply semAction_oldRegs_weakening; eauto.
  - eapply SingleMeth; eauto.
    eapply semAction_oldRegs_weakening; eauto.
Qed.

Lemma substepsInd_oldRegs_weakening:
  forall m o u l,
    SubstepsInd m o u l ->
    forall so,
      M.Sub o so ->
      SubstepsInd m so u l.
Proof.
  induction 1; simpl; intros; subst; [constructor|].
  eapply SubstepsCons; eauto.
  eapply substep_oldRegs_weakening; eauto.
Qed.

