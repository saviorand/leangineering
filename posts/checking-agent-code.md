---
title: Checking agent code against your intent
excerpt: "Coding agents write more code than anyone can read. Uncle Bob's answer is to stop reading. Mine is to get agents to write less code, and better code. Tools like Microsoft's NFV help with the better: they write down what a change is meant to do, have an agent prove the code does it, and let Lean or Dafny check the proof. What does such a proof tell you? That the code has the property. What can't it tell you? Whether the property was the right one. Can you stop reading the code? No."
date: 2026-11-22
draft: false
image: checking-agent-code-og.png
---

![The loop this post describes. The properties are frozen before the agent starts, and the checker sends refuted code back to the agent before you read anything. The dashed lines mark where a proved property can still miss.](static/blog/checking-agent-code-loop.png)

## Introduction

Coding agents now write more code than I can read. One answer is to stop reading. Robert C. Martin, better known as Uncle Bob, says his current strategy "is to not read any of the code written by my agents". Instead the code has to "run the gauntlet" of his tests, quality metrics and mutation testing[^bob]. I disagree. I think you should read all of it. The way to keep that possible is to get agents to write less code, and better code, before it reaches you.

More tests don't get you there. In Dan Luu's runs with GPT-5.6 Sol in August, asking agents to use Rust's built-in test framework roughly doubled the number of tests they wrote. In his words, "this didn't result in better correctness"[^luu]. A newer model, GPT-6 Astra, used testing techniques more effectively a month later[^astra]. Tests written by an agent still encode the agent's own idea of what the code should do, though.

On 18 November Microsoft Research described a code reviewer that works on the "better" part[^nfvpost]. It starts from the intent of a change, meaning what the change is supposed to do, and writes that intent down as precise properties. An agent then tries to prove that the code has each property, and a small, trusted program checks the proof. The researchers call the approach neuro-formal verification (NFV).

On a sample of 38 pull requests from the past month in Z3 and three other projects, the reviewer checked 217 properties, proving 161 and refuting 18[^prs]. Harmonic's Aristotle, Midspiral's LemmaScript and Don Syme's Lean Squad work in a similar way. Shuvendu Lahiri, who wrote the NFV paper, names the question they all try to answer: "does the generated code actually do what the user intended?"[^lahiri]

This post asks three questions about tools like these. What does such a proof tell you? That the code has a property you wrote down, under the assumptions it lists. What can't it tell you? Whether the property was the right one, whether it was proved about the code that runs, and whether it says what you meant. Can you stop reading the code? No. The tools send a lot of wrong code back before you see it. They also give you the intent in a few lines to read the code against. The reading stays yours.

Figure 1 shows the whole loop. Like my [last post](/blog/realworld-in-lean/), this one borrows the layout of a math paper.

## Verdicts

In 2014 a bug in OpenSSL, later named Heartbleed, let anyone on the internet read a server's memory, up to 64 kilobytes per message. That memory could hold passwords and the server's secret keys[^heartbleed]. The intent behind the fixed code fits in one sentence, which Aristotle uses as its example: "The response is never longer than the request." The tools turn a sentence like that into a checked verdict in three steps.

**Construction 1 (The model).** The code is translated into Lean or Dafny, two languages built for writing proofs about programs. Aristotle compiles C, Rust and Verilog into Lean, and LemmaScript compiles TypeScript into Dafny or Lean. Both use an ordinary compiler with no agent involved. NFV has an agent do the translation instead. That works for almost any language but adds a step you have to trust.

**Construction 2 (The property).** The intent is written down as a formal property. Lahiri calls this intent formalization. NFV derives properties "from PR descriptions, issues, discussions and captured source". In LemmaScript the intent and the property both sit in comments above an ordinary TypeScript function. This one is from LemmaScript's [demo](https://github.com/midspiral/lemmascript-claimcheck/blob/main/examples/demo.ts):

```ts
//@ contract Clamps x into the inclusive range [lo, hi]; the result never falls outside it.
//@ requires lo <= hi
//@ ensures \result >= lo && \result <= hi
export function clamp(x: number, lo: number, hi: number): number {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}
```

The `contract` line is the intent in English. The `requires` and `ensures` lines are the property. They say that if `lo <= hi` when the function is called, the return value (`\result`) lies between `lo` and `hi`. TypeScript ignores all three lines, so the code that runs doesn't change.

**Construction 3 (The proof).** An agent searches for a proof and a checker decides whether it holds. In Harmonic's words, "AI writes the proofs and Lean checks every step of them, so a result never rests on the AI being right." The checker is a small program at the core of Lean or Dafny. It accepts a step only if the step follows from the steps before it.

**Definition 1.** A *proof-backed verdict* on a property is one of three things.

- *Proved*, with the list of assumptions the proof rests on.
- *Refuted*, with an input on which the property fails.
- *Unresolved*, if neither a proof nor a counterexample was found in time.

**Remark 1 (Saying "unresolved").** NFV gives the third verdict whenever it can't settle a property. Its author tested it on small Python programs, half of them buggy. NFV settled 57% of them correctly and left most of the rest unresolved, and 92% of the verdicts it did give were right. Asking a model directly whether each program was correct produced an answer every time. Only 72% of those answers were right, and none came with anything that could be checked[^nfv].

## Limits

A proof covers what its property says and nothing else. Harmonic's [documentation](https://aristotle.harmonic.fun/docs/overview) for Aristotle is direct about it: "a behavior that isn't listed as a property hasn't been verified." So a proved property is only worth as much as the property itself.

**Definition 2.** A proved property *matches your intent* if it is a property that matters, it was proved about the code that runs, and it says what you meant.

The checker covers none of these three parts. Each of them fails in practice.

*A property that matters.* In Luu's August runs, agents implementing the Zstd compression format in Rust were told to use Lean or another proof tool. They "mostly did arithmetic proofs that didn't hit the bug-prone or risk surface areas"[^luu]. Don Syme says much the same of Lean Squad, which proved more than 1,200 theorems about three open-source codebases: "Most theorems are glorified testing"[^squad]. The newer model did better. With GPT-6 Astra, agents "seemed to use test and verification techniques more effectively", though Luu warns that he doesn't "have enough information to say why almost anything happened"[^astra].

*The code that runs.* An agent translating a program can model a slightly different program. The NFV blog post admits that "the proof alone cannot establish that the formalization faithfully captures the source program and supplied property." A compiler is more predictable, but it still simplifies. LemmaScript treats TypeScript numbers as exact integers, so its proofs say nothing about floating-point rounding. To find gaps like that, Midspiral wrote a separate tool, crosscheck, which runs the proved model and the real JavaScript on the same inputs and compares the results. This is called differential testing[^ls].

*What you meant.* Midspiral's claimcheck found a property that said less than intended in an election tally that an agent had built and proved. The intent was that the order of the ballots doesn't affect the tally. The proved property only showed that adding a ballot at the front of the list gives the same count as adding it at the end. Dafny accepted it, and it looks right at a glance. But it covers only one way of reordering the ballots[^claimcheck].

**Remark 2 (Agents move the goal).** An agent rewarded for finding a proof can also make the problem easier. The NFV blog post lists the ways an agent does this: "by overconstraining the environment, simplifying the code, or weakening the property". The author also let a single agent translate and prove in one go, with no separate stages. It proved the property for 98% of the correct programs and for 98% of the buggy ones, so half of its verdicts were wrong.

## Safeguards

The tools guard against these failures with checks that run whether or not the agent cooperates. That matters because instructions turn out to be fragile. Luu wrote a testing skill, a file of instructions an agent loads for a task. It helped GPT-5.6 Sol and hurt GPT-6 Astra. He concluded that skills like it are "very difficult" to write so that they work "across models and effort levels"[^astra]. There are four safeguards.

*Freeze the goal.* NFV writes down the translated program and the property before the proof search starts, then locks them. The agent looking for a proof may add proof steps but may not change either of them. LemmaScript's seal does the same across commits. It keeps a ledger of the proved properties of every function in the repository. Its check fails if a sealed property is changed or removed. The README puts it as "The prover proves the present; the seal protects the past."

*Read the property back.* Midspiral's claimcheck has a model that doesn't know the intent restate the formal property in plain English. A second model compares that restatement with the intent. LemmaScript builds this in, and `lsc claimcheck` compares each `contract` line with the property under it. The demo file from earlier has a second function, whose contract claims more than its property:

```ts
//@ contract Returns the larger of a and b.
//@ ensures \result >= a
export function largest(a: number, b: number): number {
  return a >= b ? a : b;
}
```

The code is correct and the property is proved, but the property never mentions `b`. In claimcheck's restatement, the function "returns a number that is greater than or equal to a". That isn't "the larger of a and b", so the [report](https://github.com/midspiral/lemmascript-claimcheck/blob/main/examples/demo.guarantees.md) marks the function as disputed. Its authors call claimcheck "a probabilistic sanity check that requires human review and approval"[^claimcheck].

*List the assumptions.* Aristotle and NFV list the assumptions behind every verdict. Harmonic's write-up on the LibTomMath library, where Aristotle fixed three bugs and proved the repaired code, has a section called "Outside the proof" for what wasn't covered[^tom].

*Stop early.* In NFV's experiments, proofs that took many attempts were more likely to be wrong. The authors' explanation is that each extra attempt gives the agent another chance to weaken the goal. So NFV caps the search at five rounds and reports what is still open as unresolved[^rounds].

## Review

All of this changes what reaches you, and how you read it.

*Feedback from the checker.* The checker sends wrong code back to the agent before it reaches you. Midspiral shows this with a bill-splitting app. Here is its `allocate` function after the agent's fix, with most of the `requires` lines left out:

```ts
//@ contract Splits total across weights so every unit is accounted for.
//@ requires total >= 0
// ...
//@ ensures sum(\result) === total
function allocate(total: number, weights: number[]): number[] {
  const W = sum(weights);
  const result = weights.map(w => Math.floor(total * w / W));
  const left = total - sum(result);  // the leftover, lost to flooring
  for (let k = 0; k < left; k++)
    result[k] = result[k] + 1;  // hand them back out
  return result;
}
```

The agent's first version ended at the `Math.floor` line, which rounds each share down. Split three ways, a total of 100 cents came to 99, so the `ensures` line failed and the proof didn't go through. The agent read the error and added the loop that hands out the leftover, and the property stayed as it was. Midspiral notes that "this correction happened without a human in the loop"[^eventab]. In their description of lemmafit, a related tool, the agent's job becomes proposing "implementation candidates that are externally checked by a deterministic process".

*Reading order.* You start with the list of properties and ask of each one whether it is what you meant. Then you read all of the code with those properties in mind, and finally what each proof assumes and what was left unresolved. The proofs themselves are the checker's job. A refuted property comes with an input on which the code fails, which is easier to act on than a feeling that something looks off. NFV's comments on pull requests are laid out this way, as Figure 2 shows.

![Part of a comment NFV leaves on a pull request: the inferred property, the outcome, an input on which it fails and a sketch of why. From the example in NFV's repository, © Microsoft Corporation, MIT License.](static/blog/checking-agent-code-nfv-report.png)

*Less to read.* A property is short. The one `ensures` line of `allocate` states what the whole function must do. A LemmaScript codebase keeps each decision in one verified function. Its rules forbid recomputing the result anywhere else, because a copy would be "a second, unverified implementation of a verified fact"[^rules]. Generated tests can go the other way. A reader of Luu's blog described a rewrite in which generated tests found about 20 bugs that more than 100 agent reviewers had missed. It took a 300,000-line test harness for a 30,000-line change. He called the result negative[^leventov].

*Refactors.* Refactors and rewrites are the easiest case. Their intent is to behave as before, and the old code already says what that means. Differential testing can compare the old and the new version directly.

In Luu's evals, differential testing was the third-worst technique with GPT-5.6 Sol. With GPT-6 Astra it came out narrowly ahead of the other 24 on his hardest task, a Rust implementation of the Pandoc document converter (Figure 3)[^diff]. The bad result is the one to remember. With Sol, agents "did the same thing twice and encoded the same bug in both versions", so the comparison only helps if the agent didn't write both sides. Aristotle offers the proof version of the same check for C code rewritten in Rust.

![Dan Luu's Pandoc results with GPT-6 Astra, redrawn from the data behind his chart. Each dot is the share of held-out tests passed at the end of a run, averaged over 25 runs, with bars of ±1 standard error. Most techniques end up within two points of giving no instructions at all.](static/blog/checking-agent-code-luu-pandoc.png)

**Remark 3 (Where it's worth it).** Proofs are most useful for the logic the rest of an app depends on, such as state changes, money and permissions. A LemmaScript codebase is split into a verified core and an unverified shell for the user interface, network and storage. One of its case studies proves the cookie handling behind a security fix in the Hono web framework.

For code that doesn't justify a proof, Lahiri describes a range of options "from lightweight tests that disambiguate likely misinterpretations, through full functional specifications for formal verification". The safeguards above still work at the light end. Before writing the code, you write the property as a property-based test, which checks it on many generated inputs. Then you freeze the test, have a second agent read it back, and keep the tests few enough to read yourself. With GPT-6 Astra, the property-based testing libraries in Luu's evals "finally resulted in tests that do what one might hope".

If you want to try this, here's where to start:

- [LemmaScript](https://github.com/midspiral/LemmaScript) for TypeScript, open source and in tech preview.
- NFV's [code reviewer](https://github.com/microsoft/neuro-formal-verification) for pull requests in most languages, an open-source prototype that runs as a GitHub Agentic Workflow.
- [Aristotle](https://www.harmonic.fun/aristotle/) for Rust, C and Verilog, a commercial service.
- [Lean Squad](https://github.com/githubnext/agentics/blob/main/docs/lean-squad.md) for Rust or C++ with Lean on the side, a GitHub Agentic Workflow you add to a repository.
- Property-based testing libraries for the light end in any language, such as Hypothesis for Python, fast-check for TypeScript and proptest for Rust.

## Lean

Lean already sits underneath several of these tools. It checks the proofs in Aristotle and Lean Squad, and LemmaScript can compile TypeScript into it. In all of them the first step, the model, is still something you have to trust. A compiler builds it in some tools and an agent in others, and both leave some behavior out.

If the code itself is written in Lean, there is nothing to translate. The program that runs is the program the proofs are about. In my RealWorld app, the function that turns an article's title into its URL slug has a theorem about it. The server calls that same function when it creates an article:

```lean
-- RealWorld/Slug.lean
theorem ofTitle_valid (title : String) : Valid (ofTitle title).toList := by
  ...

-- RealWorld/Service.lean, creating an article
let slug ← withUniqueSlug env (Slug.ofTitle a.title) fun db slug => Db.insertArticle db slug me.id a
```

`Valid` says what a slug may look like, which is lowercase letters and digits with single hyphens between words. The theorem and the server use the same `ofTitle`, so there's no translation of it to get wrong. The NFV README calls this the limit of the whole approach: "In the limit, NFV reduces to formal verification: checking a formal assertion about a closed program with no external environment in a language with a trusted logical encoding."

A real application still has a database, a network and C libraries underneath, and those sit outside the proof. What goes away is the model of your own code, and with it the chance that the model is wrong. What's left to read is also short. The Lean backend of the RealWorld app comes to 1,033 lines, the shortest of the four implementations I compared. Its theorems are about those same lines[^rw]. Getting real software to that point is what this site is about. My [RealWorld post](/blog/realworld-in-lean/) shows how far a full-stack web app in Lean gets today.

**Question 1.** Can writing down the intent be made cheap enough to do for every change? Everything above starts from properties someone wrote down, and only the developer can tell whether they are the right ones. Lahiri's paper makes the same point, that nothing but the user can judge whether a specification is correct[^lahiri]. NFV already drafts properties from the pull request, and its authors suggest asking the developer when the description is too vague. How far that can go remains open.

**Remark 4 (Who wrote it).** Claude Code did most of the research for this post at my direction. It read the NFV, claimcheck and LemmaScript repositories as well as the posts cited here, decoded the data behind Luu's charts, and wrote the first draft.

---

[^luu]: Dan Luu, ["How well do agents use test and verification techniques?"](https://danluu.com/agentic-testing/), September 2026. He ran Codex with GPT-5.6 Sol 160 times for each of 26 instructions, such as "Use Lean 4" or "Use property-based testing". Asked to use a particular technique, agents mostly wrote the tests they would have written anyway, inside whatever framework they were told to use. The runs with no instructions about testing still did better than most of the others.

[^astra]: Dan Luu, ["Test/verification technique effectiveness with Astra"](https://danluu.com/astra-testing/), November 2026, with runs from September. On the Zstd task almost every condition now came out fully correct almost every time, so he added two harder ones, implementing IMAP (80 runs per condition) and Pandoc (25 runs per condition, about $90,000 at list prices). He also disputes a widely shared claim that AI-written tests are "empirically proven to be unhelpful". In both of his evals ACL2, an older theorem prover, did better than Lean, and he expects Lean to "eventually outperform ACL2" given the effort going into it.

[^bob]: Robert C. Martin, [post on X](https://x.com/unclebobmartin/status/2080257779395154409), 23 July 2026. His full list is "Unit tests, gherkin tests, QA procedures, quality metrics, mutation testing, test coverage, and a plethora of others". In an [earlier post](https://x.com/unclebobmartin/status/2072736888478175413) he had doubts about piling on tests: "just because we can do them doesn't mean we actually should."

[^nfvpost]: Shuvendu K. Lahiri, ["Neuro-Formal Code Review: Can Proofs Help Enforce Intent at Scale?"](https://risemsr.github.io/blog/2026-11-18-neuro-formal-code-review/), RiSE MSR Blog, 18 November 2026. The method itself is in his paper ["Neuro-Formal Verification: Agentic Language-Agnostic Formal Program Reasoning"](https://arxiv.org/abs/2608.21516).

[^prs]: From the results table in the blog post. The other three projects are NVX, LiteBox and Semantic Kernel. Both kinds of verdict are about the agent's model of each change, and the post notes that the refutations "have not been fully vetted".

[^lahiri]: Shuvendu K. Lahiri, ["Intent Formalization: A Grand Challenge for Reliable Coding in the Age of AI Agents"](https://arxiv.org/abs/2603.17150), 2026. He also expects the answer to decide "whether AI makes software more reliable or merely more abundant".

[^heartbleed]: [heartbleed.com](https://heartbleed.com/), CVE-2014-0160. OpenSSL 1.0.1g fixed it on 7 April 2014. The 64-kilobyte limit applies to a single message, and an attacker could keep sending more.

[^nfv]: From the [NFV paper](https://arxiv.org/abs/2608.21516). The benchmark pairs small Python programs with buggy variants of them. The model asked directly is the paper's LLM-as-judge baseline.

[^squad]: Don Syme, ["Lean Squad: Automated Software Verification with Near-Zero Human Labour"](https://dsyme.net/2026/04/20/lean-squad-automated-software-verification-with-near-zero-human-labour/), April 2026. It proved 443 theorems about raft-rs, 518 about Cloudflare's quiche and 259 about the PX4 drone autopilot. In PX4 it found two real bugs. One is a sign function that should always return 1 or -1 but returns 0 for NaN.

[^ls]: Midspiral, ["Shallow embedding: why LemmaScript translates TypeScript straight into Dafny"](https://midspiral.com/blog/shallow-embedding-why-lemmascript-translates-typescript-straight-into-dafny/), August 2026, and the [crosscheck repository](https://github.com/midspiral/lemmascript-crosscheck). Crosscheck tries sampled inputs, so a clean run is evidence and not a proof. Since the model is compiled from the same TypeScript, crosscheck finds places where Dafny and JavaScript give different results, not places where the code doesn't match your intent.

[^claimcheck]: Fernanda Graciolli and Nada Amin, ["claimcheck: Narrowing the Gap between Proof and Intent"](https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent/). On 189 human-written Lean specifications from the VERINA benchmark, the authors judged about 30 to 40 of its disputes to be false alarms ([report](https://github.com/metareflection/claimcheck/blob/main/reports/VERINA.md)).

[^rules]: From the [rules](https://github.com/midspiral/lemmascript-skills/blob/main/lemmascript-verified-codebase-rules/SKILL.md) Midspiral gives agents working in a LemmaScript codebase.

[^rw]: Non-blank, non-comment lines without tests, as counted in the [RealWorld post](/blog/realworld-in-lean/). The TypeScript, Go and C# implementations have 1,267, 1,371 and 2,396.

[^tom]: Harmonic, ["Speed up your code without wondering what you broke"](https://www.harmonic.fun/aristotle/case-studies/libtommath/). Among other things, the section says that full modular exponentiation was benchmarked but not proved.

[^rounds]: The numbers are in a comment in NFV's [proof agent](https://github.com/microsoft/neuro-formal-verification/blob/dev/nfv/agent/invariant_agent.py). With GPT-5.5, 80% of proofs succeeded in the first round. Wrong proofs took 2.40 rounds on average, and correct ones took 1.06.

[^eventab]: Midspiral, ["LemmaScript contracts by example"](https://midspiral.com/blog/lemmascript-contracts-by-example/), November 2026. The lemmafit quote is from ["Introducing lemmafit: A Verifier in the AI Loop"](https://midspiral.com/blog/introducing-lemmafit-a-verifier-in-the-ai-loop/), March 2026.

[^diff]: Read from the data behind his [Pandoc chart](https://danluu.com/interactive/astra-testing/pandoc-spend-slider.html), which scores each run on held-out tests the agent never saw. At the end of their runs, differential-testing agents passed 45.1% of those tests on average and agents with no instructions 44.1%, and each average has a standard error of about one point. Luu's fitted curves, which adjust for spending, give the same order at $100 per run: 39.5% against 38.2%. On his [IMAP chart](https://danluu.com/interactive/astra-testing/imap-xhigh-percent-perfect.html), differential testing is in the middle, with 93.8% of runs fully correct against 95.0% for no instructions.

[^leventov]: Roman Leventov, in a comment quoted at the end of Luu's [Astra post](https://danluu.com/astra-testing/). The system automates parts of a support chat and is written in TypeScript as a statechart. Agent reviewers found about 210 bugs in total, and 4 or 5 "very 'stupid' bugs" still reached production.
