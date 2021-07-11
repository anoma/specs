module RefinedSExp.SExp

import Library.FunctionsAndRelations
import public RefinedSExp.List

%default total

infixr 7 $:
public export
data SExp : Type -> Type where
  ($:) : {atom : Type} -> atom -> List (SExp atom) -> SExp atom

public export
SList : Type -> Type
SList = List . SExp

public export
($|) : {atom : Type} -> SList atom
($|) = []

infixr 7 $+
public export
($+) : {atom : Type} -> SExp atom -> SList atom -> SList atom
($+) x l = x :: l

public export
SCons : {atom : Type} -> atom -> SList atom -> SExp atom
SCons = ($:)

public export
SNil : {atom : Type} -> SList atom
SNil = ($|)

public export
SLCons : {atom : Type} -> SExp atom -> SList atom -> SList atom
SLCons = ($+)

prefix 11 $^
public export
($^) : {atom : Type} -> atom -> SExp atom
($^) a = a $: ($|)

public export
SAtom : {atom : Type} -> atom -> SExp atom
SAtom = ($^)

prefix 11 <$
public export
(<$) : {atom : Type} -> SExp atom -> atom
(<$) (a $: _) = a

prefix 11 >$
public export
(>$) : {atom : Type} -> SExp atom -> SList atom
(>$) (_ $: l) = l

prefix 11 $+|
public export
($+|) : {atom : Type} -> SExp atom -> SList atom
($+|) x = x $+ ($|)

infixr 7 $++
public export
($++) : {atom : Type} -> SExp atom -> SExp atom -> SList atom
x $++ x' = x $+ $+| x'

infixr 7 $+^
public export
($+^) : {atom : Type} -> SExp atom -> atom -> SList atom
x $+^ a = x $++ $^ a

prefix 11 $^|
public export
($^|) : {atom : Type} -> atom -> SList atom
($^|) a = $+| ($^ a)

infixr 7 $:|
public export
($:|) : {atom : Type} -> atom -> SExp atom -> SExp atom
a $:| x = a $: $+| x

infixr 7 $^^
public export
($^^) : {atom : Type} -> atom -> atom -> SExp atom
a $^^ a' = a $:| $^ a'

infixr 7 $^+
public export
($^+) : {atom : Type} -> atom -> SList atom -> SList atom
a $^+ l = $^ a $+ l

infixr 7 $:+
public export
($:+) : {atom : Type} -> atom -> SExp atom -> SList atom
a $:+ x = a $^+ $+| x

infixr 7 $:^
public export
($:^) : {atom : Type} -> atom -> atom -> SList atom
a $:^ a' = a $:+ $^ a'

public export
record SExpFoldSig
  (atom, contextType, sp, lp : Type)
  where
    constructor SExpFoldArgs
    expElim :
      atom -> SList atom ->
      (contextType -> (contextType, lp)) ->
      contextType ->
      (contextType, sp)
    slistElim : ListFoldSig (SExp atom) contextType lp

public export
snilElim : {atom, contextType, sp, lp : Type} ->
  SExpFoldSig atom contextType sp lp ->
  (contextType -> (contextType, lp))
snilElim = nilElim . slistElim

public export
sconsElim : {atom, contextType, sp, lp : Type} ->
  SExpFoldSig atom contextType sp lp ->
  (SExp atom -> SList atom ->
   (contextType -> (contextType, lp)) ->
   contextType ->
   (contextType, lp))
sconsElim signature = consElim (slistElim signature)

public export
SExpFoldToListSig :
  {atom, contextType, sp, lp : Type} ->
  SExpFoldSig
      atom contextType sp lp ->
  ListFoldSig
      (SExp atom) contextType lp
SExpFoldToListSig expSig = ListFoldArgs (snilElim expSig) (sconsElim expSig)

mutual
  public export
  sexpFoldFlip :
    {atom, contextType, sp, lp : Type} ->
    (signature :
      SExpFoldSig
        atom contextType sp lp) ->
    (x : SExp atom) ->
    (context : contextType) ->
    (contextType, sp)
  sexpFoldFlip signature (a $: l) =
    expElim signature a l (slistFoldFlip signature l)

  public export
  slistFoldFlip :
    {atom, contextType, sp, lp : Type} ->
    (signature :
      SExpFoldSig
        atom contextType sp lp) ->
    (l : SList atom) ->
    (context : contextType) ->
    (contextType, lp)
  slistFoldFlip signature l =
    listFoldFlip {atom=(SExp atom)} (SExpFoldToListSig signature) l

public export
sexpFold : {atom, contextType, sp, lp : Type} ->
  (signature : SExpFoldSig atom contextType sp lp) ->
  (context : contextType) ->
  (x : SExp atom) ->
  (contextType, sp)
sexpFold signature = flip (sexpFoldFlip signature)

public export
slistFold :
  {atom, contextType, sp, lp : Type} ->
  (signature : SExpFoldSig atom contextType sp lp) ->
  (context : contextType) ->
  (l : SList atom) -> (contextType, lp)
slistFold signature = flip (slistFoldFlip signature)

public export
sexpFolds : {atom, contextType, sp, lp : Type} ->
  (signature : SExpFoldSig atom contextType sp lp) ->
  (context : contextType) ->
  ((x : SExp atom) -> (contextType, sp),
   (l : SList atom) -> (contextType, lp))
sexpFolds signature context =
  (sexpFold signature context, slistFold signature context)

SExpPredicate : {atom : Type} -> (contextType : SList atom -> Type) -> Type
SExpPredicate {atom} contextType =
  (predecessors : SList atom) -> (context : contextType predecessors) ->
  SExp atom -> Type

SListPredicate : {atom : Type} -> (contextType : SList atom -> Type) -> Type
SListPredicate {atom} contextType =
  (predecessors : SList atom) -> (context : contextType predecessors) ->
  SList atom -> Type

public export
record SExpDepFoldSig
  {atom : Type} {contextType : SList atom -> Type}
  (sp : SExpPredicate contextType) (lp : SListPredicate contextType)
  where
    constructor SExpDepFoldArgs
    expElim :
      (predecessors : SList atom) ->
      (a : atom) -> (l : SList atom) ->
      (recursiveCall :
        (calledContext : contextType predecessors) ->
         (contextType predecessors,
          lp predecessors calledContext l)) ->
      (context : contextType predecessors) ->
      (contextType predecessors, sp predecessors context (a $: l))
    slistElim : ListDepFoldSig {atom=(SExp atom)} lp

public export
sdepNilElim : {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  SExpDepFoldSig sp lp ->
  ((predecessors : SList atom) -> (context : contextType predecessors) ->
   (contextType predecessors, lp predecessors context []))
sdepNilElim = nilElim . slistElim

public export
sdepConsElim : {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  SExpDepFoldSig sp lp ->
  ((predecessors : SList atom) ->
   (x : SExp atom) -> (l : SList atom) ->
   (recursiveCall :
    (calledContext : contextType (x :: predecessors)) ->
    (contextType (x :: predecessors),
      lp (x :: predecessors) calledContext l)) ->
   (contextUponEntry : contextType predecessors) ->
   (contextType predecessors,
    lp predecessors contextUponEntry (x :: l)))
sdepConsElim = consElim . slistElim

mutual
  public export
  sexpDepFoldFlip :
    {atom : Type} -> {contextType : SList atom -> Type} ->
    {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
    (signature : SExpDepFoldSig sp lp) ->
    {predecessors : SList atom} ->
    (x : SExp atom) ->
    (context : contextType predecessors) ->
    (contextType predecessors, sp predecessors context x)
  sexpDepFoldFlip signature {predecessors} (a $: l) =
    SExpDepFoldSig.expElim signature predecessors a l
      (slistDepFoldFlip signature {predecessors} l)

  public export
  slistDepFoldFlip :
    {atom : Type} -> {contextType : SList atom -> Type} ->
    {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
    (signature : SExpDepFoldSig sp lp) ->
    {predecessors : SList atom} ->
    (l : SList atom) ->
    (context : contextType predecessors) ->
    (contextType predecessors, lp predecessors context l)
  slistDepFoldFlip signature {predecessors} l =
    listDepFoldFlip (slistElim signature) {predecessors} l

public export
sexpDepFold :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  (signature : SExpDepFoldSig sp lp) ->
  {predecessors : SList atom} ->
  (context : contextType predecessors) ->
  (x : SExp atom) -> (contextType predecessors, sp predecessors context x)
sexpDepFold signature context x = sexpDepFoldFlip signature x context

public export
slistDepFold :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  (signature : SExpDepFoldSig sp lp) ->
  {predecessors : SList atom} ->
  (context : contextType predecessors) ->
  (l : SList atom) -> (contextType predecessors, lp predecessors context l)
slistDepFold signature context l = slistDepFoldFlip signature l context

public export
sexpDepFolds :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  (signature : SExpDepFoldSig sp lp) ->
  {predecessors : SList atom} ->
  (context : contextType predecessors) ->
  ((x : SExp atom) -> (contextType predecessors, sp predecessors context x),
   (l : SList atom) -> (contextType predecessors, lp predecessors context l))
sexpDepFolds signature context =
  (sexpDepFold signature context, slistDepFold signature context)

public export
SExpFoldNonDepSigToDepSig :
  {atom, contextType, sp, lp : Type} ->
  (signature : SExpFoldSig atom contextType sp lp) ->
  SExpDepFoldSig 
    {atom} {contextType=(\_ => contextType)}
    (\_, _, _ => sp) (\_, _, _ => lp)
SExpFoldNonDepSigToDepSig signature =
  SExpDepFoldArgs
    (\_ => expElim signature)
    (ListDepFoldArgs (\_ => snilElim signature) (\_ => sconsElim signature))

public export
slistDepFoldFlipDef :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  (signature : SExpDepFoldSig sp lp) ->
  {predecessors : SList atom} ->
  (l : SList atom) ->
  slistDepFoldFlip signature {predecessors} l =
    listDepFoldFlip (slistElim signature) {predecessors} l
slistDepFoldFlipDef signature {predecessors} l = Refl

mutual
  export
  sexpDepFoldFlipCorrect :
    {atom, contextType, sp, lp : Type} ->
    (signature :
      SExpFoldSig atom contextType sp lp) ->
    {predecessors : SList atom} ->
    (x : SExp atom) ->
    sexpFoldFlip signature x =
      sexpDepFoldFlip
        {atom} {contextType=(\_ => contextType)}
        {sp=(\_, _, _ => sp)} {lp=(\_, _, _ => lp)}
        (SExpFoldNonDepSigToDepSig signature)
        {predecessors}
        x
  sexpDepFoldFlipCorrect signature (a $: l) =
    cong (expElim signature a l) (slistDepFoldFlipCorrect signature l)

  export
  slistDepFoldFlipCorrect :
    {atom, contextType, sp, lp : Type} ->
    (signature :
      SExpFoldSig atom contextType sp lp) ->
    {predecessors : SList atom} ->
    (l : SList atom) ->
    slistFoldFlip signature l =
      slistDepFoldFlip
        {atom} {contextType=(\_ => contextType)}
        {sp=(\_, _, _ => sp)} {lp=(\_, _, _ => lp)}
        (SExpFoldNonDepSigToDepSig signature)
        {predecessors}
        l
  slistDepFoldFlipCorrect signature [] = Refl
  slistDepFoldFlipCorrect signature {predecessors} (x :: l) =
    cong (sconsElim signature x l) (slistDepFoldFlipCorrect signature l)

export
sexpDepFoldCorrect :
  {atom, contextType, sp, lp : Type} ->
  (signature :
    SExpFoldSig atom contextType sp lp) ->
  {predecessors : SList atom} ->
  (context : contextType) ->
  (x : SExp atom) ->
  sexpFold signature context x =
    sexpDepFold
      {atom} {contextType=(\_ => contextType)}
      {sp=(\_, _, _ => sp)} {lp=(\_, _, _ => lp)}
      (SExpFoldNonDepSigToDepSig signature)
      {predecessors}
      context
      x
sexpDepFoldCorrect signature context (a $: l) =
  applyEq (sexpDepFoldFlipCorrect signature (a $: l))

export
slistDepFoldCorrect :
  {atom, contextType, sp, lp : Type} ->
  (signature :
    SExpFoldSig atom contextType sp lp) ->
  {predecessors : SList atom} ->
  (context : contextType) ->
  (l : SList atom) ->
  slistFold signature context l =
    slistDepFold
      {atom} {contextType=(\_ => contextType)}
      {sp=(\_, _, _ => sp)} {lp=(\_, _, _ => lp)}
      (SExpFoldNonDepSigToDepSig signature)
      {predecessors}
      context
      l
slistDepFoldCorrect signature context l =
  applyEq (slistDepFoldFlipCorrect signature l)

public export
record SExpDepContextFreeFoldSig
  {atom : Type} (sp : SExp atom -> Type) (lp : SList atom -> Type)
  where
    constructor SExpDepContextFreeFoldArgs
    expElim :
      (a : atom) -> (l : SList atom) ->
      (recursiveResult : lp l) ->
      sp (a $: l)
    slistElim : ListDepContextFreeFoldSig {atom=(SExp atom)} lp

public export
SExpDepContextFreeFoldSigToDepFoldSig :
  {atom : Type} -> {sp : SExp atom -> Type} -> {lp : SList atom -> Type} ->
  SExpDepContextFreeFoldSig {atom} sp lp ->
  SExpDepFoldSig
    {atom} {contextType=(\_ => ())} (\_, _ => sp) (\_, _ => lp)
SExpDepContextFreeFoldSigToDepFoldSig signature =
  SExpDepFoldArgs
    (\_, a, l, recursiveCall, _ =>
      ((), expElim signature a l (snd (recursiveCall ()))))
    (ListDepContextFreeFoldSigToDepFoldSig (slistElim signature))

public export
sexpDepContextFreeFolds : {atom : Type} ->
  {sp : SExp atom -> Type} ->
  {lp : SList atom -> Type} ->
  (signature : SExpDepContextFreeFoldSig sp lp) ->
  ((x : SExp atom) -> sp x, (l : SList atom) -> lp l)
sexpDepContextFreeFolds signature =
  let
    folds =
      sexpDepFolds (SExpDepContextFreeFoldSigToDepFoldSig signature) ()
        {predecessors=[]}
  in
  (\x => snd (fst folds x), \l => snd (snd folds l))

infixr 7 :$:
public export
data SExpForAll :
  {atom : Type} -> (depType : SExp atom -> type) -> SExp atom -> Type where
    (:$:) : {atom : Type} -> {depType : SExp atom -> Type} ->
            {a : atom} -> {l : SList atom} ->
            depType (a $: l) -> ListForAll depType l ->
            SExpForAll depType (a $: l)

public export
data SExpExists :
  {atom : Type} -> (depType : SExp atom -> type) -> SExp atom -> Type where
    (<$:) : {atom : Type} -> {depType : SExp atom -> Type} ->
            {a : atom} -> {l : SList atom} ->
            depType (a $: l) ->
            SExpExists depType (a $: l)
    (>$:) : {atom : Type} -> {depType : SExp atom -> Type} ->
            {a : atom} -> {l : SList atom} ->
            ListExists depType l ->
            SExpExists depType (a $: l)

SExpMetaPred :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  SExpPredicate contextType ->
  Type
SExpMetaPred {atom} {contextType} sp =
  (predecessors : SList atom) ->
  (context : contextType predecessors) ->
  (x : SExp atom) ->
  (contextType predecessors, sp predecessors context x) -> Type

SListMetaPred :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  SListPredicate contextType ->
  Type
SListMetaPred {atom} {contextType} lp =
  (predecessors : SList atom) ->
  (context : contextType predecessors) ->
  (l : SList atom) ->
  (contextType predecessors, lp predecessors context l) -> Type

public export
record SExpMetaFoldSig
  {atom : Type} {contextType : SList atom -> Type}
  {sp : SExpPredicate contextType} {lp : SListPredicate contextType}
  (signature : SExpDepFoldSig sp lp)
  (sdp : SExpMetaPred sp)
  (ldp : SListMetaPred lp)
  where
    constructor SExpMetaFoldArgs
    metaExpElim :
      (a : atom) -> (l : SList atom) ->
      (recursiveCall :
        (predecessors : SList atom) ->
        (calledContext : contextType predecessors) ->
        ldp predecessors calledContext l
          (slistDepFoldFlip signature l calledContext)) ->
      (predecessors : SList atom) ->
      (contextUponEntry : contextType predecessors) ->
      sdp predecessors contextUponEntry (a $: l)
        (expElim signature predecessors a l
          (slistDepFoldFlip signature l) contextUponEntry)
    metaListElim : ListMetaFoldSig {atom=(SExp atom)} (slistElim signature) ldp

public export
sMetaNilElim :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  {signature : SExpDepFoldSig sp lp} ->
  {sdp : SExpMetaPred sp} ->
  {ldp : SListMetaPred lp} ->
  SExpMetaFoldSig signature sdp ldp ->
  ((predecessors : SList atom) -> (context : contextType predecessors) ->
   ldp predecessors context []
    (sdepNilElim signature predecessors context))
sMetaNilElim = metaNilElim . metaListElim

public export
sMetaConsElim :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  {signature : SExpDepFoldSig sp lp} ->
  {sdp : SExpMetaPred sp} ->
  {ldp : SListMetaPred lp} ->
  SExpMetaFoldSig signature sdp ldp ->
  (x : SExp atom) -> (l : SList atom) ->
  (recursiveCall :
    (predecessors : SList atom) ->
    (calledContext : contextType predecessors) ->
    ldp predecessors calledContext l
      (slistDepFoldFlip signature l calledContext)) ->
  (predecessors : SList atom) ->
  (contextUponEntry : contextType predecessors) ->
  ldp predecessors contextUponEntry (x :: l)
    (sdepConsElim signature predecessors x l
      (slistDepFoldFlip signature l) contextUponEntry)
sMetaConsElim = metaConsElim . metaListElim

public export
sexpMetaFolds :
  {atom : Type} -> {contextType : SList atom -> Type} ->
  {sp : SExpPredicate contextType} -> {lp : SListPredicate contextType} ->
  {signature : SExpDepFoldSig sp lp} ->
  {sdp : SExpMetaPred sp} ->
  {ldp : SListMetaPred lp} ->
  (metaSig : SExpMetaFoldSig signature sdp ldp) ->
  ((predecessors : SList atom) -> (context : contextType predecessors) ->
    (x : SExp atom) ->
    sdp predecessors context x (sexpDepFold signature context x),
   (predecessors : SList atom) -> (context : contextType predecessors) ->
    (l : SList atom) ->
    ldp predecessors context l (slistDepFold signature context l))
sexpMetaFolds {signature} {sdp} {ldp} metaSig =
  let
    folds =
      sexpDepContextFreeFolds
        {sp=(\x =>
          (predecessors : SList atom) ->
          (context : contextType predecessors) ->
          sdp predecessors context x (sexpDepFold signature context x))}
        (SExpDepContextFreeFoldArgs
          (metaExpElim metaSig)
          (listMetaFoldArgs (metaListElim metaSig)))
  in
  (\predecessors, context, x => fst folds x predecessors context,
   \predecessors, context, l => snd folds l predecessors context)
