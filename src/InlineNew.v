Require Import Bool List String.
Require Import Lib.CommonTactics Lib.Struct Lib.StringBound Lib.ilist Lib.Word Lib.FMap.
Require Import Syntax Wf Equiv.

Require Import FunctionalExtensionality.

Set Implicit Arguments.

Section PhoasUT.
  Definition typeUT (k: Kind): Type := unit.
  Definition fullTypeUT := fullType typeUT.
  Definition getUT (k: FullKind): fullTypeUT k :=
    match k with
      | SyntaxKind _ => tt
      | NativeKind t c => c
    end.

  Fixpoint getCalls {retT} (a: ActionT typeUT retT) (cs: list DefMethT)
  : list DefMethT :=
    match a with
      | MCall name _ _ cont =>
        match getAttribute name cs with
          | Some dm => dm :: (getCalls (cont tt) cs)
          | None => getCalls (cont tt) cs
        end
      | Let_ _ ar cont => getCalls (cont (getUT _)) cs
      | ReadReg reg k cont => getCalls (cont (getUT _)) cs
      | WriteReg reg _ e cont => getCalls cont cs
      | IfElse ce _ ta fa cont =>
        (getCalls ta cs) ++ (getCalls fa cs) ++ (getCalls (cont tt) cs)
      | Assert_ ae cont => getCalls cont cs
      | Return e => nil
    end.

  Lemma getCalls_nil: forall {retT} (a: ActionT typeUT retT), getCalls a nil = nil.
  Proof.
    induction a; intros; simpl; intuition.
    rewrite IHa1, IHa2, (H tt); reflexivity.
  Qed.

  Lemma getCalls_sub: forall {retT} (a: ActionT typeUT retT) cs ccs,
                        getCalls a cs = ccs -> SubList ccs cs.
  Proof.
    induction a; intros; simpl; intuition; try (eapply H; eauto; fail).
    - simpl in H0.
      remember (getAttribute meth cs); destruct o.
      + pose proof (getAttribute_Some_body _ _ Heqo); subst.
        unfold SubList; intros.
        inv H0; [assumption|].
        eapply H; eauto.
      + eapply H; eauto.
    - simpl in H0; subst.
      unfold SubList; intros.
      apply in_app_or in H0; destruct H0; [|apply in_app_or in H0; destruct H0].
      + eapply IHa1; eauto.
      + eapply IHa2; eauto.
      + eapply H; eauto.
    - simpl in H; subst.
      unfold SubList; intros; inv H.
  Qed.

  Lemma getCalls_sub_name: forall {retT} (a: ActionT typeUT retT) cs ccs,
                             getCalls a cs = ccs -> SubList (namesOf ccs) (namesOf cs).
  Proof.
    induction a; intros; simpl; intuition; try (eapply H; eauto; fail).
    - simpl in H0.
      remember (getAttribute meth cs); destruct o.
      + pose proof (getAttribute_Some_body _ _ Heqo); subst.
        unfold SubList; intros.
        inv H0; [apply in_map; auto|].
        eapply H; eauto.
      + eapply H; eauto.
    - simpl in H0; subst.
      unfold SubList; intros.
      unfold namesOf in H0; rewrite map_app in H0.
      apply in_app_or in H0; destruct H0.
      + eapply IHa1; eauto.
      + rewrite map_app in H0; apply in_app_or in H0; destruct H0.
        * eapply IHa2; eauto.
        * eapply H; eauto.
    - simpl in H; subst.
      unfold SubList; intros; inv H.
  Qed.

  Section Exts.
    Definition getRuleCalls (r: Attribute (Action Void)) (cs: list DefMethT)
    : list DefMethT :=
      getCalls (attrType r typeUT) cs.

    Fixpoint getMethCalls (dms: list DefMethT) (cs: list DefMethT)
    : list DefMethT :=
      match dms with
        | nil => nil
        | dm :: dms' =>
          (getCalls (objVal (attrType dm) typeUT tt) cs)
            ++ (getMethCalls dms' cs)
      end.
  End Exts.

  Section Tree.
    Fixpoint isLeaf {retT} (a: ActionT typeUT retT) (cs: list string) :=
      match a with
        | MCall name _ _ cont =>
          if in_dec string_dec name cs then false else isLeaf (cont tt) cs
        | Let_ _ ar cont => isLeaf (cont (getUT _)) cs
        | ReadReg reg k cont => isLeaf (cont (getUT _)) cs
        | WriteReg reg _ e cont => isLeaf cont cs
        | IfElse ce _ ta fa cont => (isLeaf ta cs) && (isLeaf fa cs) && (isLeaf (cont tt) cs)
        | Assert_ ae cont => isLeaf cont cs
        | Return e => true
      end.

    Definition noCallDm (dm: DefMethT) (tgt: DefMethT) :=
      isLeaf (objVal (attrType dm) typeUT tt) [attrName tgt].

    Fixpoint noCallDms (dms: list DefMethT) (tgt: DefMethT) :=
      match dms with
        | nil => true
        | dm :: dms' =>
          if noCallDm dm tgt
          then noCallDms dms' tgt
          else false
      end.

    Fixpoint noCallRules (rules: list (Attribute (Action Void)))
             (tgt: DefMethT) :=
      match rules with
        | nil => true
        | r :: rules' =>
          if isLeaf (attrType r typeUT) [attrName tgt]
          then noCallRules rules' tgt
          else false
      end.

    Fixpoint noCall (m: Modules) (tgt: DefMethT) :=
      match m with
        | Mod _ rules dms =>
          (noCallRules rules tgt) && (noCallDms dms tgt)
        | ConcatMod m1 m2 => (noCall m1 tgt) && (noCall m2 tgt)
      end.

    Fixpoint noCalls' (m: Modules) (dms: list DefMethT) :=
      match dms with
        | nil => true
        | dm :: dms' =>
          (noCall m dm) && (noCalls' m dms')
      end.

    Definition noCalls (m: Modules) :=
      noCalls' m (getDmsBodies m).

  End Tree.

End PhoasUT.

Section Base.
  Variable type: Kind -> Type.

  Definition inlineArg {argT retT} (a: Expr type (SyntaxKind argT))
             (m: type argT -> ActionT type retT): ActionT type retT :=
    Let_ a m.

  Fixpoint getMethod (n: string) (dms: list DefMethT) :=
    match dms with
      | nil => None
      | {| attrName := mn; attrType := mb |} :: dms' =>
        if string_dec n mn then Some mb else getMethod n dms'
    end.
  
  Definition getBody (n: string) (dm: DefMethT) (sig: SignatureT):
    option (sigT (fun x: DefMethT => objType (attrType x) = sig)) :=
    if string_dec n (attrName dm) then
      match SignatureT_dec (objType (attrType dm)) sig with
        | left e => Some (existT _ dm e)
        | right _ => None
      end
    else None.

  Fixpoint inlineDm {retT} (a: ActionT type retT) (dm: DefMethT): ActionT type retT :=
    match a with
      | MCall name sig ar cont =>
        match getBody name dm sig with
          | Some (existT dm e) =>
            appendAction (inlineArg ar ((eq_rect _ _ (objVal (attrType dm)) _ e)
                                          type))
                         (fun ak => inlineDm (cont ak) dm)
          | None => MCall name sig ar (fun ak => inlineDm (cont ak) dm)
        end
      | Let_ _ ar cont => Let_ ar (fun a => inlineDm (cont a) dm)
      | ReadReg reg k cont => ReadReg reg k (fun a => inlineDm (cont a) dm)
      | WriteReg reg _ e cont => WriteReg reg e (inlineDm cont dm)
      | IfElse ce _ ta fa cont => IfElse ce (inlineDm ta dm) (inlineDm fa dm)
                                         (fun a => inlineDm (cont a) dm)
      | Assert_ ae cont => Assert_ ae (inlineDm cont dm)
      | Return e => Return e
    end.

End Base.

Section Exts.
  Definition inlineDmToRule (r: Attribute (Action Void)) (leaf: DefMethT)
  : Attribute (Action Void) :=
    {| attrName := attrName r;
       attrType := fun type => inlineDm (attrType r type) leaf |}.

  Definition inlineDmToRules (rules: list (Attribute (Action Void))) (leaf: DefMethT) :=
    map (fun r => inlineDmToRule r leaf) rules.

  Definition inlineDmToDm (dm leaf: DefMethT): DefMethT.
    refine {| attrName := attrName dm;
              attrType := {| objType := objType (attrType dm);
                             objVal := _ |} |}.
    unfold MethodT; intros.
    exact (inlineDm (objVal (attrType dm) ty X) leaf).
  Defined.

  Definition inlineDmToDms (dms: list DefMethT) (leaf: DefMethT) :=
    map (fun d => inlineDmToDm d leaf) dms.

  Definition inlineDmToMod (m: Modules) (leaf: string) :=
    match getAttribute leaf (getDmsBodies m) with
      | Some dm =>
        if noCallDm dm dm then
          match m with
            | Mod regs rules dms =>
              Mod regs (inlineDmToRules rules dm) (inlineDmToDms dms dm)
            | ConcatMod m1 m2 => m (* don't care *)
          end
        else m
      | None => m
    end.

  Fixpoint inlineDms' (m: Modules) (dms: list string) :=
    match dms with
      | nil => m
      | dm :: dms' => inlineDms' (inlineDmToMod m dm) dms'
    end.

  Definition inlineDms (m: Modules) := inlineDms' m (namesOf (getDmsBodies m)).

  Definition merge (m: Modules) := Mod (getRegInits m) (getRules m) (getDmsBodies m).
  (* Definition filterDms (dms: list DefMethT) (filt: list string) := *)
  (*   filter (fun dm => if in_dec string_dec (attrName dm) filt then false else true) dms. *)
  Definition inline (m: Modules) := inlineDms (merge m).
  
End Exts.

Require Import Semantics SemanticsNew.

Section HideExts.
  Definition hideMeth {A} (l: LabelTP A) (dmn: string) (m: Modules): LabelTP A :=
    match getAttribute dmn (getDmsBodies m) with
      | Some dm =>
        if noCallDm dm dm then
          match M.find dmn (dms l), M.find dmn (cms l) with
            | Some v1, Some v2 =>
              match signIsEq v1 v2 with
                | left _ => {| ruleMeth := ruleMeth l;
                               dms := M.remove dmn (dms l);
                               cms := M.remove dmn (cms l) |}
                | _ => l
              end
            | _, _ => l
          end
        else l
      | _ => l
    end.

  Fixpoint hideMeths {A} (l: LabelTP A) (dms: list string) (m: Modules): LabelTP A :=
    match dms with
      | nil => l
      | dm :: dms' => hideMeths (hideMeth l dm m) dms' (inlineDmToMod m dm)
    end.

  Lemma hideMeth_preserves_hide:
    forall {A} (l: LabelTP A) dm m,
      hide (hideMeth l dm m) = hide l.
  Proof.
    intros; destruct l as [rm dms cms].
    unfold hide, hideMeth; simpl.
    destruct (getAttribute dm (getDmsBodies m)); [|reflexivity].
    destruct (noCallDm a a); [|reflexivity].
    destruct (M.find dm dms); [|reflexivity].
    destruct (M.find dm cms); [|reflexivity].
    destruct (signIsEq t t0); [|reflexivity].
    subst; f_equal; auto; apply MF.subtractKV_remove.
  Qed.

End HideExts.

Section Facts.

  Lemma appendAction_SemAction:
    forall retK1 retK2 a1 a2 olds news1 news2 calls1 calls2
           (retV1: type retK1) (retV2: type retK2),
      SemAction olds a1 news1 calls1 retV1 ->
      SemAction olds (a2 retV1) news2 calls2 retV2 ->
      SemAction olds (appendAction a1 a2) (MF.union news1 news2) (MF.union calls1 calls2) retV2.
  Proof.
    induction a1; intros.

    - invertAction H0; specialize (H _ _ _ _ _ _ _ _ _ H0 H1); econstructor; eauto.
      apply MF.union_add.
    - invertAction H0; specialize (H _ _ _ _ _ _ _ _ _ H0 H1); econstructor; eauto.
    - invertAction H0; specialize (H _ _ _ _ _ _ _ _ _ H2 H1); econstructor; eauto.
    - invertAction H; specialize (IHa1 _ _ _ _ _ _ _ _ H H0); econstructor; eauto.
      apply MF.union_add.
    - invertAction H0.
      simpl; remember (evalExpr e) as cv; destruct cv; dest; subst.
      + eapply SemIfElseTrue.
        * eauto.
        * eassumption.
        * eapply H; eauto.
        * rewrite MF.union_assoc; reflexivity.
        * rewrite MF.union_assoc; reflexivity.
      + eapply SemIfElseFalse.
        * eauto.
        * eassumption.
        * eapply H; eauto.
        * rewrite MF.union_assoc; reflexivity.
        * rewrite MF.union_assoc; reflexivity.

    - invertAction H; specialize (IHa1 _ _ _ _ _ _ _ _ H H0);
      econstructor; eauto.
    - invertAction H; econstructor; eauto.
  Qed.

  Lemma inlineDm_correct_SemAction:
    forall (meth: DefMethT) or u1 cm1 argV retV1,
      SemAction or (objVal (attrType meth) type argV) u1 cm1 retV1 ->
      forall {retK2} a u2 cm2 (retV2: type retK2),
        MF.Disj u1 u2 -> MF.Disj cm1 cm2 ->
        Some {| objType := objType (attrType meth);
                objVal := (argV, retV1) |} =
        M.find (elt:=Typed SignT) meth cm2 ->
        SemAction or a u2 cm2 retV2 ->
        SemAction or (inlineDm a meth) (MF.union u1 u2)
                  (MF.union cm1 (M.remove meth cm2))
                  retV2.
  Proof.
    induction a; intros; simpl.

    - inv H4; destruct_existT.
      remember (getBody meth0 meth s) as ob; destruct ob.
      + unfold getBody in Heqob.
        destruct (string_dec meth0 meth); [subst|inv Heqob].
        destruct (SignatureT_dec _ _); [|inv Heqob].
        generalize dependent HSemAction; inv Heqob; intros.
        rewrite MF.find_add_1 in H3.
        inv H3; destruct_existT.
        simpl; constructor.
        admit. (* TODO: need WfAction *)

      + econstructor; eauto.
        * instantiate (1:= MF.union cm1 (M.remove meth calls)).
          instantiate (1:= mret).
          admit. (* map stuff; not trivial *)
        * apply H0; auto.
          { apply MF.Disj_comm, MF.Disj_add_2 in H2; dest.
            apply MF.Disj_comm; auto.
          }
          { admit. (* map stuff; not trivial *) }
      
    - inv H4; destruct_existT.
      constructor; auto.
    - inv H4; destruct_existT.
      econstructor; eauto.
    - inv H3; destruct_existT.
      econstructor; eauto.

      + instantiate (1:= MF.union u1 newRegs).
        admit. (* map stuff *)
      + apply IHa; auto.
        apply MF.Disj_comm, MF.Disj_add_2 in H0; dest.
        apply MF.Disj_comm; auto.

    - admit. (* if case *)

    - inv H3; destruct_existT.
      constructor; auto.

    - inv H3; destruct_existT.
      rewrite MF.find_empty in H2; inv H2.
  Qed.

  Lemma inlineDm_SemAction_intact:
    forall {retK} or a nr calls (retV: type retK),
      SemAction or a nr calls retV ->
      forall dmn dmb,
        None = M.find dmn calls ->
        SemAction or (inlineDm a (dmn :: dmb)%struct) nr calls retV.
  Proof.
    induction 1; intros.

    - simpl.
      remember (getBody meth (dmn :: dmb)%struct s) as omb;
        destruct omb.
      + exfalso; subst.
        unfold getBody in Heqomb.
        destruct (string_dec _ _); [|discriminate].
        subst; rewrite MF.find_add_1 in H0; inv H0.
      + subst.
        unfold getBody in Heqomb.
        destruct (string_dec _ _);
          [subst; rewrite MF.find_add_1 in H0; inv H0|].
        rewrite MF.find_add_2 in H0 by intuition auto.
        econstructor; eauto.

    - simpl; constructor; auto.
    - simpl; econstructor; eauto.
    - simpl; econstructor; eauto.

    - subst; eapply SemIfElseTrue; eauto.
      + apply IHSemAction1.
        rewrite MF.find_union in H1.
        destruct (M.find dmn calls1); auto.
      + apply IHSemAction2.
        rewrite MF.find_union in H1.
        destruct (M.find dmn calls1); auto; inv H1.

    - subst; eapply SemIfElseFalse; eauto.
      + apply IHSemAction1.
        rewrite MF.find_union in H1.
        destruct (M.find dmn calls1); auto.
      + apply IHSemAction2.
        rewrite MF.find_union in H1.
        destruct (M.find dmn calls1); auto; inv H1.

    - simpl; constructor; auto.
    - simpl; constructor; auto.
  Qed.

  Lemma noCallDm_SemAction_calls:
    forall mn mb or nr calls argV retV,
      noCallDm (mn :: mb)%struct (mn :: mb)%struct = true ->
      SemAction or (objVal mb type argV) nr calls retV ->
      M.find (elt:=Typed SignT) mn calls = None.
  Proof.
    intros; unfold noCallDm in H; simpl in H.
    admit. (* TODO: need equivalence *)    
  Qed.

  (* NOTE: inlining should be targeted only for basic modules *)
  Definition BasicMod (m: Modules) :=
    match m with
      | Mod _ _ _ => True
      | _ => False
    end.

  Lemma inlineDmToMod_correct_UnitStep_1:
    forall m (Hm: BasicMod m) (Hdms: NoDup (namesOf (getDmsBodies m))) dm or u l,
      UnitStep m or u l ->
      M.find dm (dms l) = M.find dm (cms l) ->
      UnitStep (inlineDmToMod m dm) or u (hideMeth l dm m).
  Proof.
    induction 3; intros; simpl in *.

    - unfold inlineDmToMod, hideMeth; simpl.
      destruct (getAttribute dm meths); try destruct (noCallDm a a);
      constructor; auto.

    - unfold inlineDmToMod, hideMeth; simpl.
      remember (getAttribute dm meths) as odm; destruct odm; [|eapply SingleRule; eauto].
      remember (noCallDm a a) as ocall; destruct ocall; [|eapply SingleRule; eauto].
      pose proof (getAttribute_Some_name _ _ Heqodm); subst.

      apply SingleRule with
      (ruleBody:= attrType (inlineDmToRule (ruleName :: ruleBody)%struct a))
        (retV:= retV); auto.
      + apply in_map with (f:= fun r => inlineDmToRule r a) in i.
        assumption.
      + simpl; rewrite MF.find_empty in H.
        destruct a; apply inlineDm_SemAction_intact; auto.

    - unfold inlineDmToMod, hideMeth; simpl.
      remember (getAttribute dm meths) as odm; destruct odm; [|eapply SingleMeth; eauto].
      remember (noCallDm a a) as ocall; destruct ocall; [|eapply SingleMeth; eauto].
      destruct a as [an ab]; simpl in *.
      pose proof (getAttribute_Some_name _ _ Heqodm); subst dm.

      destruct (string_dec an meth).
      + subst; exfalso.
        destruct meth as [mn mb]; simpl in *; subst.
        rewrite MF.find_add_1 in H.
        assert (ab = mb); subst.
        { rewrite <-(in_NoDup_getAttribute _ _ _ i Hdms) in Heqodm.
          inv Heqodm; reflexivity.
        }
        erewrite noCallDm_SemAction_calls in H; eauto.
        discriminate.
      + subst.
        rewrite MF.find_add_2 by assumption.
        rewrite MF.find_empty.
        apply SingleMeth with (meth:= inlineDmToDm meth (an :: ab)%struct)
                                (argV:= argV) (retV:= retV); auto.
        * apply in_map with (f:= fun dm => inlineDmToDm dm (an :: ab)%struct) in i.
          assumption.
        * simpl.
          rewrite MF.find_add_2 in H by assumption.
          rewrite MF.find_empty in H.
          apply inlineDm_SemAction_intact; auto.

    - exfalso; auto.
    - exfalso; auto.
  Qed.

  Lemma inlineDmToMod_correct_UnitStep_2:
    forall m or u1 u2 cm1 (meth: DefMethT) argV retV l2,
      UnitStep m or u2 l2 ->
      forall regs rules dms,
        m = Mod regs rules dms ->
        forall rm2 dm2 cm2,
          l2 = {| ruleMeth := rm2; dms := dm2; cms := cm2 |} ->
          SemAction or (objVal (attrType meth) type argV) u1 cm1 retV ->
          MF.Disj u1 u2 -> MF.Disj cm1 cm2 ->
          MF.Disj (M.add meth
                         {| objType := objType (attrType meth);
                            objVal := (argV, retV) |}
                         (M.empty _)) dm2 ->
          Some {| objType := objType (attrType meth);
                  objVal := (argV, retV) |} = M.find meth cm2 ->
          UnitStep (Mod regs (inlineDmToRules rules meth)
                        (inlineDmToDms dms meth))
                   or (MF.union u1 u2)
                   {| ruleMeth := rm2;
                      dms := dm2;
                      cms := MF.union cm1 (M.remove meth cm2) |}.
  Proof.
    induction 1; intros; subst.

    - inv H0; exfalso.
      rewrite MF.find_empty in H5; inv H5.

    - inv H; inv H0.
      apply SingleRule with
      (ruleBody:= attrType (inlineDmToRule (ruleName :: ruleBody)%struct meth))
        (retV:= retV0); auto.
      + apply in_map with (f:= fun r => inlineDmToRule r meth) in i.
        assumption.
      + simpl; eapply inlineDm_correct_SemAction; eauto.

    - inv H; inv H0.
      apply SingleMeth with (meth:= inlineDmToDm meth0 meth)
                              (argV:= argV0) (retV:= retV0); auto.
      * apply in_map with (f:= fun dm => inlineDmToDm dm meth) in i.
        assumption.
      * simpl; eapply inlineDm_correct_SemAction; eauto.

    - inv H.
    - inv H.
  Qed.

  Lemma inlineDmToRules_UnitStep_intact:
    forall m or u l (a: DefMethT),
      UnitStep m or u l ->
      forall regs rules dms,
        m = Mod regs rules dms ->
        forall rm dm cm,
          l = {| ruleMeth := rm; dms := dm; cms := cm |} ->
          M.find a cm = None ->
          UnitStep (Mod regs (inlineDmToRules rules a) dms) or u
                   {| ruleMeth := rm; dms := dm; cms := cm |}.
  Proof.
    induction 1; intros; subst.

    - inv H; inv H0; constructor; auto.
    - inv H; inv H0.
      apply SingleRule with
      (ruleBody:= attrType (inlineDmToRule (ruleName :: ruleBody)%struct a))
        (retV:= retV); auto.
      + apply in_map with (f:= fun r => inlineDmToRule r a) in i.
        assumption.
      + simpl; destruct a; apply inlineDm_SemAction_intact; auto.
    - inv H; inv H0; eapply SingleMeth; eauto.
    - inv H.
    - inv H.
  Qed.

  Lemma inlineDmToRules_UnitSteps_intact:
    forall regs rules dms or u l (a: DefMethT),
      UnitSteps (Mod regs rules dms) or u l ->
      forall rm dm cm,
        l = {| ruleMeth := rm; dms := dm; cms := cm |} ->
        M.find a cm = None ->
        UnitSteps (Mod regs (inlineDmToRules rules a) dms) or u
                  {| ruleMeth := rm; dms := dm; cms := cm |}.
  Proof.
    induction 1; intros; subst.

    - apply UnitSteps1.
      eapply inlineDmToRules_UnitStep_intact; eauto.

    - destruct l1 as [rm1 dm1 cm1], l2 as [rm2 dm2 cm2].
      simpl in *; inv H.
      specialize (IHX1 _ _ _ eq_refl).
      specialize (IHX2 _ _ _ eq_refl).
      rewrite MF.find_union in H0.
      destruct (M.find a cm1); [discriminate|].
      destruct (M.find a cm2); [discriminate|].
      apply (UnitStepsUnion (IHX1 eq_refl) (IHX2 eq_refl) c).
  Qed.

  Lemma inlineDmToDms_UnitStep_intact:
    forall m or u l (a: DefMethT),
      UnitStep m or u l ->
      forall regs rules dms,
        m = Mod regs rules dms ->
        forall rm dm cm,
          l = {| ruleMeth := rm; dms := dm; cms := cm |} ->
          M.find a cm = None ->
          UnitStep (Mod regs rules (inlineDmToDms dms a)) or u
                   {| ruleMeth := rm; dms := dm; cms := cm |}.
  Proof.
    induction 1; intros; subst.

    - inv H; inv H0; constructor; auto.
    - inv H; inv H0; eapply SingleRule; eauto.
    - inv H; inv H0.
      apply SingleMeth with
      (meth:= inlineDmToDm meth a) (argV:= argV) (retV:= retV); auto.
      + apply in_map with (f:= fun dm => inlineDmToDm dm a) in i.
        assumption.
      + simpl; destruct a; eapply inlineDm_SemAction_intact; auto.
    - inv H.
    - inv H.
  Qed.

  Lemma inlineDmToDms_UnitSteps_intact:
    forall regs rules dms or u l (a: DefMethT),
      UnitSteps (Mod regs rules dms) or u l ->
      forall rm dm cm,
        l = {| ruleMeth := rm; dms := dm; cms := cm |} ->
        M.find a cm = None ->
        UnitSteps (Mod regs rules (inlineDmToDms dms a)) or u
                  {| ruleMeth := rm; dms := dm; cms := cm |}.
  Proof.
    induction 1; intros; subst.

    - apply UnitSteps1.
      eapply inlineDmToDms_UnitStep_intact; eauto.

    - destruct l1 as [rm1 dm1 cm1], l2 as [rm2 dm2 cm2].
      simpl in *; inv H.
      specialize (IHX1 _ _ _ eq_refl).
      specialize (IHX2 _ _ _ eq_refl).
      rewrite MF.find_union in H0.
      destruct (M.find a cm1); [discriminate|].
      destruct (M.find a cm2); [discriminate|].
      apply (UnitStepsUnion (IHX1 eq_refl) (IHX2 eq_refl) c).
  Qed.

  Lemma inlineDmToMod_correct_UnitSteps_meth:
    forall regs rules dms or u1 u2 cm1 (meth: DefMethT) argV retV l2,
      UnitSteps (Mod regs rules dms) or u2 l2 ->
      forall rm2 dm2 cm2,
        l2 = {| ruleMeth := rm2; dms := dm2; cms := cm2 |} ->
        SemAction or (objVal (attrType meth) type argV) u1 cm1 retV ->
        MF.Disj u1 u2 -> MF.Disj cm1 cm2 ->
        MF.Disj (M.add meth
                       {| objType := objType (attrType meth);
                          objVal := (argV, retV) |}
                       (M.empty _)) dm2 ->
        Some {| objType := objType (attrType meth);
                objVal := (argV, retV) |} = M.find meth cm2 ->
        UnitSteps (Mod regs (inlineDmToRules rules meth)
                       (inlineDmToDms dms meth))
                  or (MF.union u1 u2)
                  {| ruleMeth := rm2;
                     dms := dm2;
                     cms := MF.union cm1 (M.remove meth cm2) |}.
  Proof.
    induction 1; intros; subst.

    - apply UnitSteps1.
      eapply inlineDmToMod_correct_UnitStep_2; eauto.

    - destruct l1 as [rml dml cml], l2 as [rmr dmr cmr]; simpl in *.
      inv H.
      specialize (IHX1 _ _ _ eq_refl H0 (MF.Disj_union_1 H1)
                       (MF.Disj_union_1 H2) (MF.Disj_union_1 H3)).
      specialize (IHX2 _ _ _ eq_refl H0 (MF.Disj_union_2 H1)
                       (MF.Disj_union_2 H2) (MF.Disj_union_2 H3)).
      rewrite MF.find_union in H4.
      
      remember (M.find meth cml) as ocml; destruct ocml.

      + remember (M.find meth cmr) as ocmr; destruct ocmr;
        [exfalso; inv c; dest; simpl in *;
         eapply MF.Disj_find_union_3; eauto|].

        specialize (IHX1 H4).
        match goal with
          | [ |- UnitSteps _ _ ?u {| cms := ?c |} ] =>
            replace u with (MF.union (MF.union u1 u0) u2)
              by admit; (* map stuff *)
              replace c with (MF.union
                                (MF.union cm1 (M.remove meth cml))
                                cmr)
              by admit (* map stuff *)
        end.

        match goal with
          | [ |- UnitSteps _ _ _ ?l ] =>
            replace l with
            (mergeLabel
               {| ruleMeth:= rml;
                  dms:= dml;
                  cms:= MF.union cm1 (M.remove meth cml) |}
               {| ruleMeth:= rmr;
                  dms:= dmr;
                  cms:= cmr |}
            ) by reflexivity
        end.
        apply UnitStepsUnion; auto.
        * eapply inlineDmToRules_UnitSteps_intact; eauto.
          eapply inlineDmToDms_UnitSteps_intact; eauto.
        * admit. (* CanCombine / map stuff *)

      + remember (M.find meth cmr) as ocmr;
        destruct ocmr; [|discriminate].

        specialize (IHX2 H4).
        match goal with
          | [ |- UnitSteps _ _ ?u {| cms := ?c |} ] =>
            replace u with (MF.union u0 (MF.union u1 u2))
              by admit; (* map stuff *)
              replace c with (MF.union
                                cml
                                (MF.union cm1 (M.remove meth cmr)))
              by admit (* map stuff *)
        end.

        match goal with
          | [ |- UnitSteps _ _ _ ?l ] =>
            replace l with
            (mergeLabel
               {| ruleMeth:= rml;
                  dms:= dml;
                  cms:= cml |}
               {| ruleMeth:= rmr;
                  dms:= dmr;
                  cms:= MF.union cm1 (M.remove meth cmr) |}
            ) by reflexivity
        end.
        apply UnitStepsUnion; auto.
        * eapply inlineDmToRules_UnitSteps_intact; eauto.
          eapply inlineDmToDms_UnitSteps_intact; eauto.
        * admit. (* CanCombine / map stuff *)
  Qed.

  Lemma inlineDmToMod_correct_UnitSteps_sub:
    forall regs rules dms (Hdms: NoDup (namesOf dms))
           or u1 u2 l1 l2 dm,
      In dm dms ->
      UnitSteps (Mod regs rules dms) or u2 l2 ->
      UnitSteps (Mod regs rules dms) or u1 l1 ->
      forall rm1 rm2 dm1 dm2 cm1 cm2 t,
        l1 = {| ruleMeth := rm1; dms := dm1; cms := cm1 |} ->
        l2 = {| ruleMeth := rm2; dms := dm2; cms := cm2 |} ->
        MF.Disj u1 u2 -> NotBothRule rm1 rm2 ->
        MF.Disj dm1 dm2 -> MF.Disj cm1 cm2 ->
        Some t = M.find dm dm1 -> Some t = M.find dm cm2 ->
        UnitSteps (Mod regs (inlineDmToRules rules dm)
                       (inlineDmToDms dms dm)) or (MF.union u1 u2)
                  {| ruleMeth := match rm1 with
                                   | Some r => Some r
                                   | None => rm2
                                 end;
                     dms := M.remove dm (MF.union dm1 dm2);
                     cms := M.remove dm (MF.union cm1 cm2) |}.
  Proof.
    induction 4; intros; subst.

    - inv u0; try (rewrite MF.find_empty in H6; inv H6; fail).
      destruct (string_dec dm meth);
        [|rewrite MF.find_add_2 in H6 by assumption;
           rewrite MF.find_empty in H6; inv H6].
      assert (dm = meth) by admit. (* NoDup property *)
      subst; clear e.
      
      rewrite MF.find_add_1 in H6 by assumption; inv H6.

      match goal with
        | [ |- UnitSteps _ _ _ {| dms := ?d; cms := ?c |} ] =>
          replace d with dm2 by admit;
            replace c with (MF.union cm1 (M.remove meth cm2)) by admit
            (* stupid map stuffs *)
      end.

      eapply inlineDmToMod_correct_UnitSteps_meth; eauto.

    - destruct l0 as [rml dml cml], l1 as [rmr dmr cmr]; simpl in *.
      inv H0; rewrite MF.find_union in H6.

      (* specialize (IHX0_1 _ _ _ _ _ _ t eq_refl eq_refl). *)
      (* specialize (IHX0_2 _ _ _ _ _ _ t eq_refl eq_refl). *)

      remember (M.find dm dmr) as odmr; destruct odmr.

      + inv H6; clear IHX0_2.
        remember (M.find dm dml) as odml; destruct odml;
        [exfalso; inv c; dest; simpl in *;
         eapply MF.Disj_find_union_3 with (m1:= dmr) (m2:= dml);
         eauto|].
        admit.

      + clear IHX0_1.
        admit.
  Qed.

  Lemma inlineDmToMod_correct_UnitSteps:
    forall m (Hm: BasicMod m) or nr l dm,
      NoDup (namesOf (getDmsBodies m)) ->
      UnitSteps m or nr l ->
      M.find dm (dms l) = M.find dm (cms l) ->
      UnitSteps (inlineDmToMod m dm) or nr (hideMeth l dm m).
  Proof.
    induction 3; intros;
    [constructor; apply inlineDmToMod_correct_UnitStep_1; auto|].

    destruct l1 as [rm1 dm1 cm1], l2 as [rm2 dm2 cm2]; simpl in *.
    remember (M.find dm (MF.union dm1 dm2)) as odmv.
    destruct odmv.

    - unfold inlineDmToMod, hideMeth in *; simpl in *.
      rewrite <-Heqodmv, <-H0; simpl.
      destruct (signIsEq t t); [clear e|elim n; auto].

      remember (getAttribute dm (getDmsBodies m)) as odm; destruct odm;
      [|apply (UnitStepsUnion X1 X2 c)].
      remember (noCallDm a a) as oc; destruct oc;
      [|apply (UnitStepsUnion X1 X2 c)].

      pose proof (getAttribute_Some_name _ _ Heqodm); subst.
      destruct m as [regs rules dms|]; [|exfalso; inv Hm].

      unfold CanCombine in c; dest; simpl in *.
      rewrite MF.find_union in Heqodmv; rewrite MF.find_union in H0.
      remember (M.find a dm1) as odmv1; destruct odmv1.
      
      + inv Heqodmv.
        remember (M.find a cm1) as ocmv1; destruct ocmv1.
        * (* left-side inlined *)
          inv H0; specialize (IHX1 eq_refl).
          destruct (signIsEq t t); [clear e|elim n; auto].

          do 2 rewrite MF.remove_union.
          match goal with
            | [ |- UnitSteps _ _ _ ?l ] =>
              replace l with
              (mergeLabel {| ruleMeth:= rm1;
                             dms:= M.remove a dm1;
                             cms:= M.remove a cm1 |}
                          {| ruleMeth:= rm2;
                             dms:= M.remove a dm2;
                             cms:= M.remove a cm2 |})
                by reflexivity
          end.
          apply UnitStepsUnion; auto.
          { assert (M.find a dm2 = None)
              by (destruct (MF.Disj_find_None a H3); auto;
                  rewrite H0 in Heqodmv1; inv Heqodmv1).
            assert (M.find a cm2 = None)
              by (destruct (MF.Disj_find_None a H4); auto;
                  rewrite H5 in Heqocmv1; inv Heqocmv1).
            do 2 rewrite MF.remove_find_None by assumption.
            eapply inlineDmToRules_UnitSteps_intact; eauto.
            eapply inlineDmToDms_UnitSteps_intact; eauto.
          }
          { repeat split; simpl; auto.
            { apply MF.Disj_remove_1, MF.Disj_remove_2; assumption. }
            { apply MF.Disj_remove_1, MF.Disj_remove_2; assumption. }
          }

        * pose proof (getAttribute_Some_body _ _ Heqodm).
          eapply inlineDmToMod_correct_UnitSteps_sub; eauto.

      + remember (M.find a cm1) as ocmv1; destruct ocmv1.
        * clear IHX1 IHX2; inv H0.
          replace (MF.union u1 u2) with (MF.union u2 u1)
            by (apply MF.union_comm; apply MF.Disj_comm; auto).
          replace (match rm1 with | Some r => Some r | None => rm2 end) with
          (match rm2 with | Some r => Some r | None => rm1 end)
            by (destruct rm1, rm2; intuition idtac; destruct H2; discriminate).
          replace (MF.union dm1 dm2) with (MF.union dm2 dm1)
            by (apply MF.union_comm; apply MF.Disj_comm; auto).
          replace (MF.union cm1 cm2) with (MF.union cm2 cm1)
            by (apply MF.union_comm; apply MF.Disj_comm; auto).
          pose proof (getAttribute_Some_body _ _ Heqodm).
          eapply inlineDmToMod_correct_UnitSteps_sub; eauto;
          try (apply MF.Disj_comm; auto).
          destruct H2; unfold NotBothRule; intuition auto.
        * (* right-side inlined *)
          rewrite <-Heqodmv, <-H0 in IHX2.
          specialize (IHX2 eq_refl).
          destruct (signIsEq t t); [clear e|elim n; auto].

          do 2 rewrite MF.remove_union.
          match goal with
            | [ |- UnitSteps _ _ _ ?l ] =>
              replace l with
              (mergeLabel {| ruleMeth:= rm1;
                             dms:= M.remove a dm1;
                             cms:= M.remove a cm1 |}
                          {| ruleMeth:= rm2;
                             dms:= M.remove a dm2;
                             cms:= M.remove a cm2 |})
                by reflexivity
          end.
          apply UnitStepsUnion; auto.
          { do 2 rewrite MF.remove_find_None by auto.
            eapply inlineDmToRules_UnitSteps_intact; eauto.
            eapply inlineDmToDms_UnitSteps_intact; eauto.
          }
          { repeat split; simpl; auto.
            { apply MF.Disj_remove_1, MF.Disj_remove_2; assumption. }
            { apply MF.Disj_remove_1, MF.Disj_remove_2; assumption. }
          }

    - unfold hideMeth in *; simpl in *; rewrite <-Heqodmv.
      rewrite MF.find_union in Heqodmv.
      destruct (M.find dm dm1); [discriminate|].
      destruct (M.find dm dm2); [discriminate|].
      rewrite MF.find_union in H0.
      destruct (M.find dm cm1); [discriminate|].
      destruct (M.find dm cm2); [discriminate|].
      specialize (IHX1 eq_refl); specialize (IHX2 eq_refl).

      destruct (getAttribute dm (getDmsBodies m));
        try destruct (noCallDm a a);
        apply (UnitStepsUnion IHX1 IHX2 c).
  Qed.

  Lemma inlineDmToMod_wellHidden:
    forall {A} (l: LabelTP A) m a,
      wellHidden l m ->
      wellHidden l (inlineDmToMod m a).
  Proof.
    admit. (* Inlining proof *)
  Qed.

  Lemma wellHidden_find:
    forall {A} m a (l: LabelTP A),
      In a (namesOf (getDmsBodies m)) ->
      wellHidden (hide l) m ->
      M.find a (dms l) = M.find a (cms l).
  Proof.
    admit.
  Qed.

  Lemma inlineDmToMod_basicMod:
    forall m a,
      BasicMod m ->
      BasicMod (inlineDmToMod m a).
  Proof.
    destruct m; intros; unfold inlineDmToMod;
    destruct (getAttribute _ _); try destruct (noCallDm a0 a0);
    auto.
  Qed.

  Lemma inlineDmToMod_dms_names:
    forall m a,
      namesOf (getDmsBodies (inlineDmToMod m a)) =
      namesOf (getDmsBodies m).
  Proof.
    destruct m; intros; simpl in *.
    - unfold inlineDmToMod.
      destruct (getAttribute _ _); try destruct (noCallDm _ _);
      try (reflexivity; fail).
      simpl; clear.

      induction dms; auto.
      simpl; f_equal; auto.

    - unfold inlineDmToMod.
      destruct (getAttribute _ _); try destruct (noCallDm _ _);
      reflexivity.
  Qed.

  Lemma inlineDms'_correct_UnitSteps:
    forall cdms m (Hm: BasicMod m)
           (Hdms: NoDup (namesOf (getDmsBodies m)))
           (Hcdms: SubList cdms (namesOf (getDmsBodies m)))
           or nr l,
      UnitSteps m or nr l ->
      wellHidden (hide l) m ->
      UnitSteps (inlineDms' m cdms) or nr (hideMeths l cdms m).
  Proof.
    induction cdms; [auto|].
    intros; simpl.

    apply SubList_cons_inv in Hcdms; dest.

    apply IHcdms; auto.
    - apply inlineDmToMod_basicMod; auto.
    - rewrite inlineDmToMod_dms_names; auto.
    - rewrite inlineDmToMod_dms_names; auto.
    - apply inlineDmToMod_correct_UnitSteps; auto.
      eapply wellHidden_find; eauto.
    - apply inlineDmToMod_wellHidden.
      rewrite hideMeth_preserves_hide; auto.
  Qed.

  Definition InlinableDm (m: Modules) (dm: string) :=
    match getAttribute dm (getDmsBodies m) with
      | Some dmb =>
        if noCallDm dmb dmb then True else False
      | _ => False
    end.

  Inductive Inlinable (m: Modules): list string -> Prop :=
  | InlinableNil: Inlinable m nil
  | InlinableCons:
      forall dm dms,
        Inlinable (inlineDmToMod m dm) dms ->
        InlinableDm m dm ->
        Inlinable m (dm :: dms).

  Definition hideMethF {A} (l: LabelTP A) (dmn: string): LabelTP A :=
    match M.find dmn (dms l), M.find dmn (cms l) with
      | Some v1, Some v2 =>
        match signIsEq v1 v2 with
          | left _ => {| ruleMeth := ruleMeth l;
                         dms := M.remove dmn (dms l);
                         cms := M.remove dmn (cms l) |}
          | _ => l
        end
      | _, _ => l
    end.

  Fixpoint hideMethsF {A} (l: LabelTP A) (dms: list string): LabelTP A :=
    match dms with
      | nil => l
      | dm :: dms' => hideMethsF (hideMethF l dm) dms'
    end.

  Lemma hideMethsF_hide:
    forall dmsAll {A} (l: LabelTP A),
      MF.InDomain (dms l) dmsAll ->
      hideMethsF l dmsAll = hide l.
  Proof.
    admit. (* True, but not trivial *)
  Qed.

  Lemma hideMethsF_UnitSteps_hide:
    forall m or nr l,
      UnitSteps m or nr l ->
      hideMethsF l (namesOf (getDmsBodies m)) = hide l.
  Proof.
    intros; apply hideMethsF_hide.
    admit. (* Semantics proof *)
  Qed.

  Lemma hideMeth_hideMethF:
    forall m dm {A} (l: LabelTP A),
      InlinableDm m dm ->
      hideMeth l dm m = hideMethF l dm.
  Proof.
    intros; unfold InlinableDm in H; unfold hideMeth.
    destruct (getAttribute dm (getDmsBodies m)); [|intuition idtac].
    destruct (noCallDm a a); [|intuition idtac].
    reflexivity.
  Qed.

  Lemma hideMeths_hideMethsF:
    forall m dms,
      Inlinable m dms ->
      forall {A} (l: LabelTP A),
        hideMeths l dms m = hideMethsF l dms.
  Proof.
    induction 1; intros; [reflexivity|].
    simpl; rewrite hideMeth_hideMethF; auto.
  Qed.
    
  Lemma hideMeths_UnitSteps_hide:
    forall m or nr l,
      UnitSteps m or nr l ->
      Inlinable m (namesOf (getDmsBodies m)) ->
      hideMeths l (namesOf (getDmsBodies m)) m = hide l.
  Proof.
    intros.
    rewrite hideMeths_hideMethsF; auto.
    eapply hideMethsF_UnitSteps_hide; eauto.
  Qed.

  Lemma inlineDms_correct_UnitSteps:
    forall m (Hm: BasicMod m) (Hdms: NoDup (namesOf (getDmsBodies m))) or nr l,
      UnitSteps m or nr l ->
      Inlinable m (namesOf (getDmsBodies m)) ->
      wellHidden (hide l) m ->
      UnitSteps (inlineDms m) or nr (hide l).
  Proof.
    intros.
    erewrite <-hideMeths_UnitSteps_hide; eauto.
    apply inlineDms'_correct_UnitSteps; auto.
    apply SubList_refl.
  Qed.

  Lemma inlineDms_wellHidden:
    forall {A} (l: LabelTP A) m,
      wellHidden l m ->
      wellHidden l (inlineDms m).
  Proof.
    intros; unfold inlineDms.
    remember (namesOf (getDmsBodies m)) as dms; clear Heqdms.
    generalize dependent m; induction dms; intros; [assumption|].
    apply IHdms; auto.
    apply inlineDmToMod_wellHidden; auto.
  Qed.

  Lemma hide_idempotent:
    forall {A} (l: LabelTP A), hide l = hide (hide l).
  Proof.
    admit. (* Semantics proof *)
  Qed.

  Lemma inlineDms_correct:
    forall m (Hm: BasicMod m) (Hdms: NoDup (namesOf (getDmsBodies m)))
           (Hin: Inlinable m (namesOf (getDmsBodies m)))
           or nr l,
      Step m or nr l ->
      Step (inlineDms m) or nr l.
  Proof.
    induction 4; intros.
    subst; pose proof (inlineDms_correct_UnitSteps Hm Hdms u Hin w).

    apply MkStep with (l:= hide l); auto.
    - apply hide_idempotent.
    - apply inlineDms_wellHidden; auto.
  Qed.

  Lemma merge_preserves_step:
    forall m or nr l,
      Step m or nr l ->
      Step (merge m) or nr l.
  Proof.
    admit.
  Qed.

  (* Lemma filter_preserves_step: *)
  (*   forall regs rules dmsAll or nr l filt, *)
  (*     Step (Mod regs rules dmsAll) or nr l -> *)
  (*     MF.NotOnDomain (dms l) filt -> *)
  (*     Step (Mod regs rules (filterDms dmsAll filt)) or nr l. *)
  (* Proof. *)
  (* Qed. *)

  (* Instead of filter, use below *)
  Lemma step_dms_hidden:
    forall m or nr l,
      Step m or nr l ->
      MF.NotOnDomain (dms l) (getCmsMod m).
  Proof.
    intros; inv X.
    unfold wellHidden in H0.
    destruct (hide l0); simpl in *; intuition.
  Qed.

  Theorem inline_correct:
    forall m (Hdms: NoDup (namesOf (getDmsBodies m)))
           (Hin: Inlinable (merge m) (namesOf (getDmsBodies m)))
           or nr l,
      Step m or nr l ->
      Step (inline m) or nr l.
  Proof.
    intros; unfold inline.
    apply inlineDms_correct.
    - unfold BasicMod, merge; auto.
    - simpl; auto.
    - simpl; auto.
    - apply merge_preserves_step; auto.
  Qed.

End Facts.

