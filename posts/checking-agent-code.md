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

More tests don't get you there. In Dan Luu's August runs, asking agents to use Rust's built-in test framework roughly doubled the number of tests they wrote, "but this didn't result in better correctness"[^luu]. A newer model tested better a month later[^astra]. Still, a test an agent writes encodes the agent's own idea of what the code should do.

On 18 November Microsoft Research described a code reviewer that works on the "better" part[^nfvpost]. It starts from the intent of a change, meaning what the change is supposed to do, and writes that intent down as precise properties. An agent tries to prove that the code has each property, and a small, trusted program checks the proof. The researchers call this neuro-formal verification (NFV), and on 38 recent pull requests it checked 217 properties[^prs]. Harmonic's Aristotle, Midspiral's LemmaScript and Don Syme's Lean Squad work in a similar way.

This post asks three questions about tools like these. What does such a proof tell you? That the code has a property you wrote down, under the assumptions it lists. What can't it tell you? Whether the property was the right one, whether it was proved about the code that runs, and whether it says what you meant. Can you stop reading the code? No, but less of it reaches you, and what does has already been checked against the intent. Figure 1 shows the loop. Like my [last post](/blog/realworld-in-lean/), this one borrows the layout of a math paper.

## Verdicts

In 2014 a bug in OpenSSL, later named Heartbleed, let anyone on the internet read a server's memory, including passwords and secret keys[^heartbleed]. The intent behind the fix fits in one sentence, which Aristotle uses as its example: "The response is never longer than the request." Three steps turn a sentence like that into a checked verdict.

**Construction 1 (The model).** The code is translated into Lean or Dafny, two languages built for writing proofs about programs. Aristotle compiles C, Rust and Verilog into Lean, and LemmaScript compiles TypeScript into Dafny or Lean, both with an ordinary compiler. NFV has an agent do the translation instead. That works for almost any language but adds a step you have to trust.

**Construction 2 (The property).** The intent is written down as a formal property. Shuvendu Lahiri, who wrote the NFV paper, calls this intent formalization[^lahiri]. NFV derives properties from a pull request's description, issues and discussions. In LemmaScript the intent and the property sit in comments above an ordinary TypeScript function, as in this example from its [demo](https://github.com/midspiral/lemmascript-claimcheck/blob/main/examples/demo.ts):

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

**Construction 3 (The proof).** An agent searches for a proof and a checker decides whether it holds. In Harmonic's words, "AI writes the proofs and Lean checks every step of them, so a result never rests on the AI being right." The checker is a small program at the core of Lean or Dafny, and it accepts a step only if the step follows from the ones before it.

**Definition 1.** A *proof-backed verdict* on a property is one of three things.

- *Proved*, with the list of assumptions the proof rests on.
- *Refuted*, with an input on which the property fails.
- *Unresolved*, if neither a proof nor a counterexample was found in time.

**Remark 1 (Saying "unresolved").** A checker that can say "unresolved" is right more often when it does answer. On NFV's benchmark of small Python programs, 92% of its verdicts were right. A model asked directly answered every program, but only 72% of its answers were right, and none came with anything that could be checked[^nfv].

## Limits

A proof covers what its property says and nothing else. Harmonic's [documentation](https://aristotle.harmonic.fun/docs/overview) puts it plainly, warning that "a behavior that isn't listed as a property hasn't been verified." So a proof is only worth as much as its property.

**Definition 2.** A proved property *matches your intent* if it is a property that matters, it was proved about the code that runs, and it says what you meant.

The checker covers none of these three parts, and each of them fails in practice.

*A property that matters.* In Luu's August runs, agents implementing the Zstd compression format in Rust were told to use Lean or another proof tool. They "mostly did arithmetic proofs that didn't hit the bug-prone or risk surface areas"[^luu]. Don Syme says much the same of Lean Squad, which proved more than 1,200 theorems about three open-source codebases: "Most theorems are glorified testing"[^squad].

*The code that runs.* An agent translating a program can model a slightly different program. The NFV blog post admits that "the proof alone cannot establish that the formalization faithfully captures the source program and supplied property." A compiler is more predictable, but it still simplifies. LemmaScript treats TypeScript numbers as exact integers, so its proofs say nothing about floating-point rounding. Midspiral's crosscheck looks for gaps like that. It runs the proved model and the real JavaScript on the same inputs and compares the results, which is called differential testing[^ls].

*What you meant.* Midspiral's claimcheck caught this in an election tally that an agent had built and proved. The intent was that the order of the ballots doesn't affect the tally. The proved property only showed that adding a ballot at the front of the list gives the same count as adding it at the end. Dafny accepted it, and it looks right at a glance. But it covers only one way of reordering the ballots[^claimcheck].

**Remark 2 (Agents move the goal).** An agent rewarded for finding a proof can also make the problem easier. The NFV blog post lists the ways: "by overconstraining the environment, simplifying the code, or weakening the property". The authors also let a single agent translate and prove in one go. It proved the property for 98% of the buggy programs as well as 98% of the correct ones, so half of its verdicts were wrong.

## Safeguards

The tools guard against these failures with checks that don't depend on the agent following instructions. That matters, because instructions turn out to be fragile. Luu's own testing skill, a file of instructions an agent loads for a task, helped GPT-5.6 Sol and hurt the newer GPT-6 Astra[^astra]. There are four safeguards.

*Freeze the goal.* NFV locks the translated program and the property before the proof search starts, so the agent can add proof steps but can't change what is being proved. LemmaScript's seal does the same across commits. Its check fails if a proved property is changed or removed, or in its README's words, "The prover proves the present; the seal protects the past."

*Read the property back.* Midspiral's claimcheck has one model restate the formal property in plain English without seeing the intent, and a second model compare the two. LemmaScript runs it on every `contract` line. The demo file from earlier has a function whose contract claims more than its property:

```ts
//@ contract Returns the larger of a and b.
//@ ensures \result >= a
export function largest(a: number, b: number): number {
  return a >= b ? a : b;
}
```

The code is correct and the property is proved, but the property never mentions `b`. Its restatement, "returns a number that is greater than or equal to a", isn't "the larger of a and b", so the [report](https://github.com/midspiral/lemmascript-claimcheck/blob/main/examples/demo.guarantees.md) marks the function as disputed[^claimcheck].

*List the assumptions.* Aristotle and NFV list the assumptions behind every verdict. Harmonic's write-up on the LibTomMath library, where Aristotle fixed three bugs and proved the repaired code, has a section called "Outside the proof" for what wasn't covered[^tom].

*Stop early.* In NFV's experiments, proofs that took many attempts were more likely to be wrong. The authors put that down to each attempt being another chance to weaken the goal. So NFV caps the search at five rounds and reports anything still open as unresolved[^rounds].

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

The agent's first version ended at the `Math.floor` line, which rounds each share down, so 100 cents split three ways came to 99. The `ensures` line failed. The agent read the error and added the loop that hands out the leftover, and the property stayed as it was. Midspiral notes that "this correction happened without a human in the loop"[^eventab].

*Reading order.* You read the properties first and ask whether each one is what you meant. Then you read all of the code with them in mind, and finally the assumptions and whatever is unresolved. The proofs are the checker's job. A refuted property comes with an input on which the code fails, which is easier to act on than a hunch. NFV's comments on pull requests are laid out this way (Figure 2).

![Part of a comment NFV leaves on a pull request: the inferred property, the outcome, an input on which it fails and a sketch of why. From the example in NFV's repository, © Microsoft Corporation, MIT License.](static/blog/checking-agent-code-nfv-report.png)

*Less to read.* A property is short. The one `ensures` line of `allocate` states what the whole function must do. LemmaScript's rules also keep each decision in one verified function and forbid recomputing it anywhere else, since a copy would be "a second, unverified implementation of a verified fact"[^rules]. Generated tests can go the other way. A reader of Luu's blog needed a 300,000-line generated test harness for a 30,000-line rewrite, and called the result negative[^leventov].

*Refactors.* Refactors and rewrites are the easiest case, because their intent is to behave as before and the old code says what that means. Differential testing compares the old and new versions directly.

In Luu's evals, differential testing was the third-worst technique with GPT-5.6 Sol. With GPT-6 Astra it was narrowly the best on his hardest task, implementing the Pandoc document converter (Figure 3)[^diff]. The bad result is the one to remember. With Sol, agents "did the same thing twice and encoded the same bug in both versions", so the comparison only helps if the agent didn't write both sides. Aristotle offers the proof version of the same check for C code rewritten in Rust.

![Dan Luu's Pandoc results with GPT-6 Astra, redrawn from the data behind his chart. Each dot is the share of held-out tests passed at the end of a run, averaged over 25 runs, with bars of ±1 standard error. Most techniques end up within two points of giving no instructions at all.](static/blog/checking-agent-code-luu-pandoc.png)

**Remark 3 (Where it's worth it).** Proofs pay off most for the logic the rest of an app depends on, such as state changes, money and permissions. A LemmaScript codebase keeps that logic in a verified core, apart from the user interface, network and storage. For code that doesn't justify a proof, the same safeguards work with a property-based test, which checks a property on many generated inputs. You write it before the code, freeze it, have a second agent read it back, and keep the tests few enough to read yourself.

If you want to try this, here's where to start:

- [LemmaScript](https://github.com/midspiral/LemmaScript) for TypeScript, open source and in tech preview.
- NFV's [code reviewer](https://github.com/microsoft/neuro-formal-verification) for pull requests in most languages, an open-source prototype that runs as a GitHub Agentic Workflow.
- [Aristotle](https://www.harmonic.fun/aristotle/) for Rust, C and Verilog, a commercial service.
- [Lean Squad](https://github.com/githubnext/agentics/blob/main/docs/lean-squad.md) for Rust or C++ with Lean on the side, a GitHub Agentic Workflow you add to a repository.
- Property-based testing libraries for the light end in any language, such as Hypothesis for Python, fast-check for TypeScript and proptest for Rust.

## Lean

Lean already sits underneath several of these tools. It checks the proofs in Aristotle and Lean Squad, and LemmaScript can compile TypeScript into it. In all of them the model from Construction 1 is still something you have to trust.

If the code itself is written in Lean, there is nothing to translate. In my RealWorld app, the function that turns an article's title into its URL slug has a theorem about it. The server calls that same function when it creates an article:

```lean
-- RealWorld/Slug.lean
theorem ofTitle_valid (title : String) : Valid (ofTitle title).toList := by
  ...

-- RealWorld/Service.lean, creating an article
let slug ← withUniqueSlug env (Slug.ofTitle a.title) fun db slug => Db.insertArticle db slug me.id a
```

`Valid` says a slug is lowercase letters and digits with single hyphens between words. The theorem is about the code that runs. NFV's README calls this the limit of the whole approach, "checking a formal assertion about a closed program with no external environment in a language with a trusted logical encoding." A real app still has a database, a network and C libraries outside the proof, but there is no model of your own code left to get wrong.

Theorems aren't the only tool, either. Lean is a general-purpose language, and a claim can rest on whatever it can bear. The community [style guide](https://github.com/saviorand/lean-style-guide) I started orders the options in a principle from Paul Butcher: "Give each claim the strongest guarantee it admits: a type, then a theorem, then a property test, then an example." Three of the RealWorld app's guarantees come from types alone. If a handler's types don't match its route, for example, the code doesn't compile. Property-based tests run with [Plausible](https://github.com/leanprover-community/plausible), and the loop in Figure 1 works the same with a frozen property test in place of a theorem.

**Remark 4 (Agents and Lean today).** Agents don't use Lean well on their own yet. In Luu's Astra runs, agents told to use Lean 4 came out slightly below those given no instructions on both tasks, as Figure 3 shows for Pandoc. The gaps are within the noise, but neither shows Lean helping[^lean]. In those evals, though, Lean sat beside Rust code, so the agents proved things about their own model of it, the gap this section removes. A program written in Lean is a setup his evals didn't test. The style guide is my attempt at the guidance agents need, and I haven't measured whether it helps.

Getting real software to that point is what this site is about. The Lean backend of the RealWorld app came to 1,033 lines, the shortest of the four implementations I compared, so reading all of it is realistic[^rw]. My [RealWorld post](/blog/realworld-in-lean/) shows how far a full-stack web app in Lean gets today.

**Question 1.** Can writing down the intent be made cheap enough to do for every change? Everything above starts from properties someone wrote down, and only the developer can tell whether they are the right ones. Lahiri makes the same point, that nothing but the user can judge whether a specification is correct. NFV already drafts properties from the pull request, and its authors suggest asking the developer when the description is too vague. How far that can go remains open.

**Remark 5 (Who wrote it).** Claude Code did most of the research for this post at my direction. It read the NFV, claimcheck and LemmaScript repositories as well as the posts cited here, decoded the data behind Luu's charts, and wrote the first draft.

---

[^bob]: Robert C. Martin, [post on X](https://x.com/unclebobmartin/status/2080257779395154409), 23 July 2026. His full list is "Unit tests, gherkin tests, QA procedures, quality metrics, mutation testing, test coverage, and a plethora of others". In an [earlier post](https://x.com/unclebobmartin/status/2072736888478175413) he had doubts about piling on tests: "just because we can do them doesn't mean we actually should."

[^luu]: Dan Luu, ["How well do agents use test and verification techniques?"](https://danluu.com/agentic-testing/), September 2026. He ran Codex with GPT-5.6 Sol 160 times for each of 26 instructions, such as "Use Lean 4" or "Use property-based testing". Asked to use a particular technique, agents mostly wrote the tests they would have written anyway, inside whatever framework they were told to use. The runs with no instructions about testing still did better than most of the others.

[^astra]: Dan Luu, ["Test/verification technique effectiveness with Astra"](https://danluu.com/astra-testing/), November 2026, with runs from September. With GPT-6 Astra, agents "seemed to use test and verification techniques more effectively", though he warns he doesn't "have enough information to say why almost anything happened". The Zstd task was now solved almost every time, so he added two harder ones, implementing IMAP (80 runs per condition) and Pandoc (25 runs per condition, about $90,000 at list prices). He concluded that testing skills are "very difficult" to write so that they work "across models and effort levels", and he disputes a widely shared claim that AI-written tests are "empirically proven to be unhelpful".

[^nfvpost]: Shuvendu K. Lahiri, ["Neuro-Formal Code Review: Can Proofs Help Enforce Intent at Scale?"](https://risemsr.github.io/blog/2026-11-18-neuro-formal-code-review/), RiSE MSR Blog, 18 November 2026. The method itself is in his paper ["Neuro-Formal Verification: Agentic Language-Agnostic Formal Program Reasoning"](https://arxiv.org/abs/2608.21516).

[^prs]: From the results table in the blog post: 161 properties proved and 18 refuted, on a sample of pull requests from the past month in Z3, NVX, LiteBox and Semantic Kernel. Both kinds of verdict are about the agent's model of each change, and the post notes that the refutations "have not been fully vetted".

[^heartbleed]: [heartbleed.com](https://heartbleed.com/), CVE-2014-0160. An attacker could read up to 64 kilobytes per message and keep sending messages. OpenSSL 1.0.1g fixed it on 7 April 2014.

[^lahiri]: Shuvendu K. Lahiri, ["Intent Formalization: A Grand Challenge for Reliable Coding in the Age of AI Agents"](https://arxiv.org/abs/2603.17150), 2026. It opens with the question these tools try to answer, "does the generated code actually do what the user intended?", and argues that "there is no oracle for specification correctness other than the user".

[^nfv]: From the [NFV paper](https://arxiv.org/abs/2608.21516). The benchmark pairs small Python programs with buggy variants of them. NFV settled 57% of them correctly and left most of the rest unresolved. The model asked directly is the paper's LLM-as-judge baseline.

[^squad]: Don Syme, ["Lean Squad: Automated Software Verification with Near-Zero Human Labour"](https://dsyme.net/2026/04/20/lean-squad-automated-software-verification-with-near-zero-human-labour/), April 2026. It proved 443 theorems about raft-rs, 518 about Cloudflare's quiche and 259 about the PX4 drone autopilot. In PX4 it found two real bugs. One is a sign function that should always return 1 or -1 but returns 0 for NaN.

[^ls]: Midspiral, ["Shallow embedding: why LemmaScript translates TypeScript straight into Dafny"](https://midspiral.com/blog/shallow-embedding-why-lemmascript-translates-typescript-straight-into-dafny/), August 2026, and the [crosscheck repository](https://github.com/midspiral/lemmascript-crosscheck). Crosscheck tries sampled inputs, so a clean run is evidence and not a proof. Since the model is compiled from the same TypeScript, crosscheck finds places where Dafny and JavaScript give different results, not places where the code doesn't match your intent.

[^claimcheck]: Fernanda Graciolli and Nada Amin, ["claimcheck: Narrowing the Gap between Proof and Intent"](https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent/). They call it "a probabilistic sanity check that requires human review and approval". On 189 human-written Lean specifications from the VERINA benchmark, they judged about 30 to 40 of its disputes to be false alarms ([report](https://github.com/metareflection/claimcheck/blob/main/reports/VERINA.md)).

[^tom]: Harmonic, ["Speed up your code without wondering what you broke"](https://www.harmonic.fun/aristotle/case-studies/libtommath/). Among other things, the section says that full modular exponentiation was benchmarked but not proved.

[^rounds]: The numbers are in a comment in NFV's [proof agent](https://github.com/microsoft/neuro-formal-verification/blob/dev/nfv/agent/invariant_agent.py). With GPT-5.5, 80% of proofs succeeded in the first round. Wrong proofs took 2.40 rounds on average, and correct ones took 1.06.

[^eventab]: Midspiral, ["LemmaScript contracts by example"](https://midspiral.com/blog/lemmascript-contracts-by-example/), November 2026.

[^rules]: From the [rules](https://github.com/midspiral/lemmascript-skills/blob/main/lemmascript-verified-codebase-rules/SKILL.md) Midspiral gives agents working in a LemmaScript codebase.

[^leventov]: Roman Leventov, in a comment quoted at the end of Luu's [Astra post](https://danluu.com/astra-testing/). The system automates parts of a support chat and is written in TypeScript as a statechart. Generated tests found about 20 bugs that more than 100 agent reviewers had missed, out of about 230 in total, and 4 or 5 "very 'stupid' bugs" still reached production.

[^diff]: Read from the data behind his [Pandoc chart](https://danluu.com/interactive/astra-testing/pandoc-spend-slider.html), which scores each run on held-out tests the agent never saw. At the end of their runs, differential-testing agents passed 45.1% of those tests on average and agents with no instructions 44.1%, and each average has a standard error of about one point. Luu's fitted curves, which adjust for spending, give the same order at $100 per run: 39.5% against 38.2%. On his [IMAP chart](https://danluu.com/interactive/astra-testing/imap-xhigh-percent-perfect.html), differential testing is in the middle, with 93.8% of runs fully correct against 95.0% for no instructions.

[^lean]: On Pandoc, agents told to use Lean 4 passed 42.3% of the held-out tests against 44.1% with no instructions. On IMAP, 90.0% of their runs were fully correct against 95.0%. The gaps are about 1.6 and 1.2 standard errors. Luu doesn't describe what the Lean agents did in these runs. In August they mostly proved arithmetic and leaned on ordinary Rust tests. In both of his evals ACL2, an older theorem prover, did better than Lean, and he expects Lean to "eventually outperform ACL2" given the effort going into it.

[^rw]: Non-blank, non-comment lines without tests, as counted in the [RealWorld post](/blog/realworld-in-lean/). The TypeScript, Go and C# implementations have 1,267, 1,371 and 2,396.
