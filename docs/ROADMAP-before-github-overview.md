# Roadmap CodSpeed — Pré-stage & Suivi long terme

**Poste :** Systems Engineer Intern — instrumentation de perf, profiling, runtime Linux, benchmark runners.
**Objectif :** un seul document de référence — une partie pré-stage sur 20 jours (concret, orienté pratique), et une partie suivi long terme pour tout le stage (reprend ton tracker Notion, réorganisé par priorité). L'idée n'est pas de tout finir en 20 jours, mais d'arriver avec des bases solides le 31 août, puis de continuer à approfondir en parallèle du travail réel.

Priorités du mentor, dans l'ordre :
1. Processus Linux (fork/exec, mémoire virtuelle, `/proc/<pid>`, chargement des shared objects)
2. Syscalls courants
3. Intégrations CodSpeed (`codspeed-rust` + `instrument-hooks`, puis CLI `codspeed`)
4. Graphes basiques (BFS/DFS)
5. Stack unwinding (frame pointer vs DWARF) — via `samply`
6. eBPF basics — via `memtrack`

---

# Partie 1 — Pré-stage (J1-J20, avant le 31 août)

---

## Semaine 1 (J1-J7) — Fondations Linux : processus, mémoire, syscalls

**But de la semaine :** être capable d'expliquer, sans notes, ce qui se passe entre `execve()` et le premier `main()`, et de naviguer dans `/proc` à l'aise.

- **J1 — fork/exec/wait**
  - Théorie : différence `fork()` (copie du processus, COW) vs `exec*()` (remplacement de l'image mémoire) vs `posix_spawn`. Pourquoi `codspeed exec -- ./binaire` doit gérer un sous-processus.
  - Pratique : écrire un petit `tmp.c` (tu en as déjà un) qui fait `fork()` + `execve()` d'un binaire de `playground`, et observer avec `strace -f`.

- **J2 — Mémoire virtuelle**
  - Théorie : pages, table des pages, `mmap`, COW, différence heap/stack/mmap regions, ASLR.
  - Pratique : lancer `playground` en benchmark et regarder `/proc/<pid>/maps` et `/proc/<pid>/smaps` pendant l'exécution. Identifier les régions (binaire, libc, stack, heap).

- **J3 — `/proc/<pid>` en profondeur**
  - Théorie : `status`, `stat`, `maps`, `smaps`, `fd/`, `task/<tid>` (threads).
  - Pratique : script bash qui, pendant un `codspeed exec`, dump périodiquement `/proc/<pid>/status` et `/proc/<pid>/maps` dans un fichier — comprendre à quoi un instrument de mesure "regarde" pour avoir des métriques (RSS, threads, etc.).

- **J4 — Chargement des shared objects**
  - Théorie : rôle de `ld.so`, `LD_PRELOAD`, résolution dynamique (PLT/GOT), pourquoi `instrument-hooks` s'injecte probablement via une lib partagée.
  - Pratique : `ldd` sur le binaire compilé de `playground`, puis essayer un `LD_PRELOAD` avec une petite lib qui hook `malloc` et print un message.

- **J5 — Syscalls courants**
  - Théorie : `clone`, `ptrace`, `perf_event_open`, `mmap`, `read/write`, `ioctl` — dans quel contexte un profiler/instrumenteur les utilise.
  - Pratique : `strace -c` sur un run `codspeed exec` de `playground` → regarder la distribution des syscalls, essayer d'expliquer chacun des plus fréquents.

- **J6 — `ptrace` et attache de processus**
  - Théorie : comment un débogueur/profiler s'attache à un processus (`PTRACE_ATTACH`, `PTRACE_PEEKTEXT`, signaux `SIGSTOP`/`SIGTRAP`).
  - Pratique : lire le mini-exemple `simpleton/stack-unwind-samples` (backtrace par frame pointer via `ptrace`) pour voir le principe en ~30 lignes de C.

- **J7 — Consolidation + petit projet**
  - Écrire un mini "process inspector" en Rust ou C dans `playground` : lance un binaire enfant, et pendant qu'il tourne, lit `/proc/<pid>/maps` + compte les syscalls avec `strace` piloté par script. Objectif : que ce soit toi qui "instrumentes" un process, pas juste que tu lises sur le sujet.

---

## Semaine 2 (J8-J14) — Intégrations CodSpeed + stack unwinding

**But de la semaine :** comprendre concrètement comment `codspeed-rust` → `instrument-hooks` → CLI `codspeed` s'articulent, et ce qu'apporte `samply` pour l'unwinding.

- **J8 — Setup produit sans wizard IA (conseil du mentor)**
  - Doc à lire : [What is CodSpeed?](https://codspeed.io/docs/what-is-codspeed), [Quickstart → section "Manual setup"](https://codspeed.io/docs/index.md) (ignore la partie Wizard/AI Setup), [Running Benchmarks in GitHub Actions](https://codspeed.io/docs/integrations/ci/github-actions/index.md), [Configuring GitHub Actions for CodSpeed](https://codspeed.io/docs/integrations/ci/github-actions/configuration.md).
  - Suivre la doc pas à pas sur `codspeed-playground`, configurer l'action GitHub `CodSpeedHQ/action` toi-même, sans passer par l'assistant d'installation.
  - Vérifier que tu comprends chaque ligne du YAML (`cli/codspeed.yml`, workflow GitHub Actions).

- **J9 — `codspeed-rust` : le harness**
  - Doc à lire : [Writing Benchmarks in Rust](https://codspeed.io/docs/benchmarks/rust/index.md), [criterion.rs compatibility layer](https://codspeed.io/docs/benchmarks/rust/criterion.md), [CodSpeed CLI](https://codspeed.io/docs/cli.md).
  - Lire aussi le repo `CodSpeedHQ/codspeed-rust` en parallèle : comment les macros de bench s'articulent avec `criterion`, ce qui est spécifique à CodSpeed vs standard.
  - Pratique : ajouter 2-3 nouveaux benchmarks dans `playground/benches/` qui couvrent des patterns différents (boucle CPU-bound, allocation mémoire, I/O simulé).

- **J10 — `instrument-hooks`**
  - Lire `CodSpeedHQ/instrument-hooks` : c'est la couche commune utilisée par tous les langages (Rust, C++, Node, Python…). Repérer l'API exposée (start/stop d'un bench, marqueurs).
  - Pratique : essayer de tracer, dans le code, le chemin depuis un appel `#[codspeed::bench]` (ou équivalent) jusqu'à l'appel dans `instrument-hooks`.

- **J11 — Les 3 instruments en détail**
  - Doc à lire : [Performance Instruments (overview)](https://codspeed.io/docs/instruments/index.md), [CPU Simulation Instrument](https://codspeed.io/docs/instruments/cpu/index.md), [Benchmark Variance](https://codspeed.io/docs/instruments/cpu/regression-causes.md), [Reducing Variance](https://codspeed.io/docs/instruments/cpu/reducing-variance.md), [Walltime Instrument Overview](https://codspeed.io/docs/instruments/walltime/index.md), [Macro Runners](https://codspeed.io/docs/features/macro-runners.md).
  - Lire aussi `CodSpeedHQ/codspeed` (le repo CLI) pour voir comment ces instruments sont implémentés.
  - Pratique : lancer `codspeed exec -- ./ton-binaire` en local, comparer avec un run en mode `--mode walltime`, regarder la différence de sortie et comprendre pourquoi walltime a besoin d'un runner dédié pour être stable.

- **J12 — Stack unwinding : frame pointer**
  - Théorie : comment un unwinder par frame pointer marche (`rbp` chaîné), pourquoi certains binaires compilés en `-fomit-frame-pointer` cassent ça.
  - Pratique : compiler `playground` avec et sans `-fno-omit-frame-pointer`, comparer un `perf record`/`samply record` sur les deux.

- **J13 — Stack unwinding : DWARF (via `samply`)**
  - Théorie : `.eh_frame`, CFI (Call Frame Information), pourquoi c'est plus lent mais plus fiable sans frame pointer.
  - Doc à lire : [Performance Profiling and Flame Graphs](https://codspeed.io/docs/features/profiling.md) — pour relier l'unwinding à ce que CodSpeed affiche réellement en flame graph.
  - Pratique : lire le sous-module `samply` dans le repo `codspeed` (mentionné par ton mentor), faire un `samply record` sur `playground`, ouvrir le profil dans le Firefox Profiler UI.

- **J14 — Consolidation**
  - Résumer en quelques phrases (pour toi) : quand CodSpeed a besoin de frame pointers, quand il tombe sur DWARF, et où `samply`/`framehop` interviennent dans la chaîne.

---

## Semaine 3 (J15-J20) — eBPF, graphes, et projet final

- **J15 — eBPF : les bases**
  - Théorie : qu'est-ce qu'un programme eBPF (bytecode vérifié, s'exécute dans le kernel, attaché à un hook : syscall, kprobe, tracepoint), le rôle du verifier, les maps eBPF pour faire remonter des données en userspace.
  - Ressource : l'article "DWARF-based Stack Walking Using eBPF" de Polar Signals donne un bon exemple concret de ce qu'eBPF peut/ne peut pas faire pour du stack walking.

- **J16 — `memtrack` dans le repo CodSpeed**
  - Doc à lire : [Memory instrument](https://codspeed.io/docs/instruments/memory/index.md) — la vue "produit" de ce que `memtrack` fait sous le capot.
  - Lire la crate `memtrack` dans le repo open-source `codspeed` — c'est l'exemple concret cité par ton mentor pour le tracking mémoire via eBPF (allocations heap, peak usage).
  - Pratique : identifier quels hooks (probablement `malloc`/`free` via uprobes, ou tracepoints) sont utilisés, et comment les données remontent jusqu'au rapport.

- **J17 — eBPF pratique légère**
  - Si le temps le permet : essayer un tutoriel type "hello world eBPF" (bpftrace ou libbpf-rs) pour juste tracer les appels `openat` d'un processus. L'objectif n'est pas de devenir expert eBPF mais de démystifier "ça fait quoi concrètement".

- **J18 — Graphes : BFS/DFS**
  - Théorie : BFS (parcours par niveaux, file), DFS (parcours en profondeur, pile/récursion), complexité, cas d'usage (résolution de dépendances, détection de cycles — pertinent si CodSpeed doit résoudre des graphes d'appel ou de dépendances).
  - Pratique : implémenter BFS et DFS en Rust dans `playground`, **et les benchmarker avec CodSpeed** — bonne occasion de relier graphes + outil CodSpeed dans le même exercice.

- **J19 — Mini-projet : bout en bout**
  - Objectif : dans `codspeed-playground`, avoir un mini pipeline qui illustre plusieurs des concepts vus :
    1. Un binaire avec plusieurs fonctions à profiler (dont BFS/DFS).
    2. Des benchmarks `codspeed-rust` dessus, exécutés via la CI GitHub Actions.
    3. Une inspection manuelle du process (`/proc/<pid>/maps`, `strace`) pendant un run local.
    4. Un profil `samply` du binaire pour visualiser les stacks.

- **J20 — Révision + questions pour l'équipe**
  - Relire tes notes de la semaine 1 à 3, identifier 3-5 questions précises à poser le premier jour (ex : "comment `instrument-hooks` distingue les instruments au runtime ?", "pourquoi walltime nécessite un runner dédié ?").
  - Repos GitHub bien nettoyé et poussé, prêt à montrer si besoin.

---

## Repos et ressources de référence (pré-stage)

- `CodSpeedHQ/codspeed` — CLI, instruments (simulation / mémoire eBPF / walltime), sous-module `samply`, crate `memtrack`
- `CodSpeedHQ/codspeed-rust` — harness Rust
- `CodSpeedHQ/instrument-hooks` — couche commune à tous les langages
- `CodSpeedHQ/action` — GitHub Action officielle
- `mstange/samply` — profiler CLI, unwinding frame pointer + DWARF, sous-module de `codspeed`
- `mstange/framehop` — lib Rust de stack unwinding utilisée par `samply`
- Polar Signals — article "DWARF-based Stack Walking Using eBPF" (bon complément pour comprendre les limites d'eBPF sur l'unwinding)

## Doc CodSpeed — ce qu'il n'est pas utile de lire maintenant

Index complet : https://codspeed.io/docs/llms.txt — pratique pour voir toutes les pages d'un coup. Pour ta prépa, tu peux ignorer sans problème : les guides pour les autres langages (Python/Node/Go/Java/C++, sauf curiosité), les instruments Database/MongoDB, Wizard/MCP/Agent Skills, Security/Data Deletion, Seats & Billing, Roles & Permissions. Ce sont des pages produit générales, pas du contenu technique lié à ton poste.

## Principe général (pré-stage)

Pas de lecture de bouquin en continu : chaque concept ci-dessus est associé à un test dans ton repo. Si un jour tu bloques sur la théorie, passe direct à l'exercice pratique — souvent ça débloque la compréhension plus vite que de continuer à lire.

---

# Partie 2 — Suivi long terme (pendant tout le stage)

Cette partie reprend ton tracker (Notion), réorganisée en 3 tiers de priorité. Le but : garder une vision claire de ce qui sert directement ta mission au quotidien, ce qui approfondit en arrière-plan, et ce qui est de l'ordre de la culture générale à picorer quand tu as du temps mort. Objectif CDI : les tiers 1 et 2 sont ce qui te rend concrètement bon dans le poste ; le tier 3 nourrit ta compréhension globale sans jamais bloquer le reste — continue à tout approfondir, juste dans cet ordre d'attaque.

### Tier 1 — Cœur du poste, à faire vivre en continu

- **CodSpeed Documentation** — pas un "one-shot" : à chaque nouvelle feature/instrument que tu croises en vrai au travail, va lire la page correspondante.
- **CodSpeed Github** — idem, en continu : chaque repo (`codspeed`, `codspeed-rust`, `instrument-hooks`, `action`) mérite d'être relu à mesure que tu touches du code lié.
- **Exploring in depth Linux Syscall API** — explicitement demandé par ton mentor, à garder actif tout le stage (ex: `man 2` de chaque syscall que tu croises en `strace`).
- **CodSpeed integration to krpsim** (Perf/Optimisation 42) — je le remonte en priorité haute : c'est le meilleur exercice possible (intégrer CodSpeed sur un vrai projet à toi, pas un repo jouet). Bon candidat pour remplacer/compléter le mini-projet J19 de la Partie 1 si tu as le temps avant le 31 août, sinon fais-le dès les premières semaines du stage.
- **eBPF** — mentionné explicitement par ton mentor ; continue au-delà des bases vues en J15-J17, en particulier tout ce qui touche au tracking mémoire (`memtrack`) et au tracing (uprobes/kprobes/tracepoints).

### Tier 2 — Renforce la compréhension système, à avancer en parallèle

- **42 Kernel Projects en Rust (kfs-1, kfs-2, kfs-3)** — x86_32, Multiboot, VGA, Shell, GDT, Segmentation, Paging, IDT. Lien réel avec le poste : GDT/Segmentation/Paging = la mémoire virtuelle que ton mentor a mentionnée, vue "par en dessous". Pas urgent avant le 31 août, mais très rentable comme fil de fond sur plusieurs mois — garde `kfs-1` en C fait, continue `xv6` + *Writing an OS in Rust* à ton rythme.
- **Operating Systems: Three Easy Pieces** — passe en mode référence : au lieu de le lire dans l'ordre, ouvre le chapitre qui correspond à ce que tu creuses ce jour-là (virtualisation mémoire, processus, concurrence...).
- **Systems Performance: Enterprise and the Cloud** (Brendan Gregg) — très pertinent pour un rôle de perf engineering, mais gros pavé. Même traitement que OSTEP : cible les chapitres CPU, mémoire, et tracing/eBPF en priorité plutôt que de le lire en séquence.
- **The Rust Programming Language** — continue jusqu'au bout à ton rythme, tu en as besoin au quotidien pour écrire du Rust idiomatique dans les repos CodSpeed.

### Tier 3 — Culture générale, à picorer sans pression

- **A Philosophy of Software Design** — bon livre, mais assez déconnecté du sujet précis du stage (design logiciel général vs perf/systèmes). À lire quand tu as un moment mort, sans objectif de vitesse.

### Item à clarifier

- **"( More )"** — c'était pour ce que le Systems Engineer allait potentiellement ajouter ; à compléter quand tu as plus de détails de sa part.

## Principe général (suivi long terme)

Comme en pré-stage : privilégie toujours l'exercice pratique sur la lecture longue. Pour les tiers 2 et 3, la règle est "lire un chapitre pertinent quand un vrai problème te pousse à le lire", pas "avancer le pourcentage du livre". Le Tier 1 doit rester vivant tout le stage — c'est ce qui compte le plus pour la suite (CDI).

