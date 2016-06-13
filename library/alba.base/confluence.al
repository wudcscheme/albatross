use
    endorelation
end

A: ANY

is_diamond (r:{A,A}): ghost BOOLEAN
    -> all(a,b,c) r(a,b) ==> r(a,c) ==> some(d) r(b,d) and r(c,d)

{:
In the following we prove that any relation transfers the diamond property to
its reflexive and transitive closures.

In order to prove that a closure 's' has the diamond property we have to prove

    s(a,b) ==> s(a,c) ==> some(d) s(b,d) and s(c,d)

Because of the two premises we can do two induction proofs and we usually have
to use two nested induction proofs to prove the desired property. In order to
simplify matters we use an intermediate lemma where 'r' is the original
relation and 's' is the corresponding closure:

    s(a,b) ==> r(b,c) ==> some(d) r(b,d) and s(c,d)

        a ---> c          --->  r
        .      .          ...>  s
        .      .
        v      v
        b ---> d

This requires one induction proof. In the second step we prove the desired
property with another induction proof.

All closures (reflexive and transitive) have a base rule of the form

    r(x,y) ==> s(x,y)

which states that the closure contains the original relation. This case
requires in both cases the same proof for the intermediate lemma. Therefore we
factor out this proof in another lemma.

:}



all(a,b,c:A, r,s:{A,A})
        -- Base case for both intermediate lemmas
    require
        r.is_diamond
        r <= s
        r(a,b)
        r(a,c)
    ensure
        some(d) r(b,d) and s(c,d)
    via some(d)
            require
                r(b,d)
                r(c,d)
            proof
                r(b,d) and s(c,d)
    end






{: Theorem: If 'r' is a diamond relation then its reflexive closure is a
            diamond as well.

   We use an intermediate lemma to prove the claim:

   Lemma: (r.reflexive)(a,b) ==> r(a,c) ==> some(d) r(b,d) and (r.reflexive)(d,b)

            a ---> c         --->  r
            .      .         ...>  r.reflexive
            .      .
            v      v
            b ---> d

:}

all(a,b,c:A, r:{A,A})
    require
        r.is_diamond
        (r.reflexive)(a,b)
        r(a,c)
    ensure
        some(d) r(b,d) and (r.reflexive)(c,d)

        inspect
            (r.reflexive)(a,b)

        case all(a,b) r(a,b) ==> (r.reflexive)(a,b)
        proof
            r <= r.reflexive

        case all(a,b) r(a,b) ==> (r.reflexive)(a,a)
        proof
            r(a,c) and (r.reflexive)(c,c)

        case all(a,b) r(a,b) ==> (r.reflexive)(b,b)
        proof
            r(b,c) and (r.reflexive)(c,c)
    end






all(a,b,c:A, r:{A,A})
    require
        r.is_diamond
        (r.reflexive)(a,c)
        (r.reflexive)(a,b)
    ensure
        some(d) (r.reflexive)(b,d) and (r.reflexive)(c,d)

        inspect
            (r.reflexive)(a,c)
        case all(a,c) r(a,c) ==> (r.reflexive)(a,c)
            via some(d)
                    require
                        r(b,d)
                        (r.reflexive)(c,d)
                    proof
                        (r.reflexive)(b,d) and (r.reflexive)(c,d)

        case all(a,c) r(a,c) ==> (r.reflexive)(a,a)
            via some(d)
                    require
                        r(b,d)
                        (r.reflexive)(c,d)
                    proof
                        (r.reflexive)(b,b) and (r.reflexive)(a,b)

        case all(a,c) r(a,c) ==> (r.reflexive)(c,c)
            proof
                (r.reflexive)(b,b) and (r.reflexive)(c,b)
    end





all(r:{A,A})
    ensure
        r.is_diamond  ==>  r.reflexive.is_diamond
    end



{: Theorem: If 'r' is a diamond relation then its transitive closure is a
            diamond as well.

   We use an intermediate lemma to prove the claim:

   Lemma: (+r)(a,b) ==> r(a,c) ==> some(d) r(b,d) and (+r)(d,b)

            a ---> c         --->  r
            .      .         ...>  +r
            .      .
            v      v
            b ---> d
:}


all(a,b,c:A, r:{A,A})
         -- Intermediate lemma for the transitive closure.
    require
        r.is_diamond
        (+r)(a,b)
        r(a,c)
    ensure
        some(d) r(b,d) and (+r)(c,d)

        inspect
            (+r)(a,b)
        case
            all(a,b) r(a,b) ==> (+r)(a,b)
        proof
            r <= +r

        case
            all(a,b,d) (+r)(a,b) ==> r(b,d) ==> (+r)(a,d)
            {:      a ----> c           --->        r
                    .       .           ...>       +r
                    .       .
                    v       v
                    b ----> e
                    |       |
                    v       v
                    d ----> f
            :}
            via some(e)
                    require
                        r(b,e)
                        (+r)(c,e)
                    via some(f)
                            require
                                r(d,f)
                                r(e,f)
                            proof
                                r(b,d)
                                r(d,f) and (+r)(c,f)
    end



all(a,b,c:A, r:{A,A})
    require
        r.is_diamond
        (+r)(a,c)
        (+r)(a,b)
    ensure
        some(d) (+r)(b,d) and (+r)(c,d)

        inspect
            (+r)(a,c)
        case
            all(a,c) r(a,c) ==> (+r)(a,c)
                   via some(d)
                           require
                               r(b,d)
                               (+r)(c,d)
                           proof
                               r(a,c)
                               (+r)(b,d) and (+r)(c,d)
        case
            all(a,c,e) (+r)(a,c) ==> r(c,e) ==> (+r)(a,e)
            {:  a . . .> c ---> e           --->        r
                .        .      .           ...>       +r
                .        .      .
                v        v      v
                b . . .> d ---> f
            :}
            via some(d)
                    require
                        (+r)(b,d)
                        (+r)(c,d)
                    via some(f)
                            require
                                r(d,f)
                                (+r)(e,f)
                            proof
                                (+r)(b,f) and (+r)(e,f)
    end




all(r:{A,A}) ensure r.is_diamond ==> (+r).is_diamond end



is_confluent(r:{A,A}): ghost BOOLEAN
        -- Is the relation confluent i.e. is its transitive closure a diamond?
    -> (+r).is_diamond
