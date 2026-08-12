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

**Note de calibrage (v2) :** tu m'as montré `fdtrace` — un traceur syscall en Rust via `ptrace(PTRACE_SYSCALL)`, avec extraction de chemins depuis la mémoire tracée (`PTRACE_PEEKDATA`), résolution `/proc/<pid>/maps` + `addr2line`, tracking de sessions open/read/write/close/dup, et un choix motivé d'écarter `LD_PRELOAD` (binaires statiques, syscalls directs) et eBPF (complexité d'environnement) pour ce projet. Ça change complètement le calibrage : ce n'est plus "confirmer que tu connais ptrace/syscalls", c'est "tu as déjà construit un mini `instrument-hooks`". Le J1 "checklist" de la version précédente est donc supprimé — remplacé par un exercice qui part directement de `fdtrace` et attaque ses limites connues (documentées par toi-même dans le README : pas de suivi fork/clone, symbolisation via `addr2line` plutôt qu'un lecteur DWARF natif, pas de vrai stack unwinding). C'est exactement l'écart entre ce que tu as et ce que `samply`/`instrument-hooks` font en plus.

---

## J1 — Étendre `fdtrace` : combler les limites connues

Plutôt qu'un exercice jouet, on part de ton propre outil et on attaque ses limitations documentées — c'est plus formateur et ça te donne un vrai projet à montrer en entretien de fin de stage.

- **Suivre `fork`/`clone`/threads** — actuellement seul le process initial est tracé. Ajoute `PTRACE_O_TRACEFORK`/`PTRACE_O_TRACECLONE` (via `PTRACE_SETOPTIONS`) pour suivre les enfants. C'est directement pertinent pour CodSpeed : un benchmark runner doit gérer le cas où le binaire benchmarké spawn des sous-process.
- **Filtrer le bruit `ld.so`/libc** — le README note que la sortie inclut le chargement dynamique. Ajoute un mode qui filtre `/etc/ld.so.cache` et `libc.so.6` pour ne garder que l'activité "applicative" — bon exercice sur `/proc/<pid>/maps` pour distinguer les régions.

Garde le reste de `fdtrace` en référence tout du long de cette prépa (voir J8 pour l'upgrade DWARF).

---

## J2-J4 — CodSpeed : setup manuel, harness Rust, CLI

**But :** comprendre concrètement comment `codspeed-rust` → `instrument-hooks` → CLI `codspeed` s'articulent. C'est la partie 100% nouvelle (spécifique au produit), donc c'est ici que le temps doit vraiment aller.

- **J2 — Setup produit sans wizard IA (conseil du mentor)**
  - Doc à lire : [What is CodSpeed?](https://codspeed.io/docs/what-is-codspeed), [Quickstart → section "Manual setup"](https://codspeed.io/docs/index.md) (ignore la partie Wizard/AI Setup), [Running Benchmarks in GitHub Actions](https://codspeed.io/docs/integrations/ci/github-actions/index.md), [Configuring GitHub Actions for CodSpeed](https://codspeed.io/docs/integrations/ci/github-actions/configuration.md).
  - Suivre la doc pas à pas sur `codspeed-playground`, configurer l'action GitHub `CodSpeedHQ/action` toi-même, sans passer par l'assistant d'installation. Vérifier que tu comprends chaque ligne du YAML.

- **J3 — `codspeed-rust` (harness) + `instrument-hooks` (couche commune)**
  - Doc à lire : [Writing Benchmarks in Rust](https://codspeed.io/docs/benchmarks/rust/index.md), [criterion.rs compatibility layer](https://codspeed.io/docs/benchmarks/rust/criterion.md), [CodSpeed CLI](https://codspeed.io/docs/cli.md).
  - Lire `CodSpeedHQ/codspeed-rust` (macros de bench vs `criterion` standard) puis `CodSpeedHQ/instrument-hooks` (API commune à tous les langages : start/stop, marqueurs) — tracer le chemin depuis un appel de macro jusqu'à `instrument-hooks`.
  - Pratique : ajouter 2-3 benchmarks dans `playground/benches/` sur des patterns différents (CPU-bound, allocation mémoire, I/O simulé).

- **J4 — Les 3 instruments en détail**
  - Doc à lire : [Performance Instruments (overview)](https://codspeed.io/docs/instruments/index.md), [CPU Simulation Instrument](https://codspeed.io/docs/instruments/cpu/index.md), [Benchmark Variance](https://codspeed.io/docs/instruments/cpu/regression-causes.md), [Reducing Variance](https://codspeed.io/docs/instruments/cpu/reducing-variance.md), [Walltime Instrument Overview](https://codspeed.io/docs/instruments/walltime/index.md), [Macro Runners](https://codspeed.io/docs/features/macro-runners.md).
  - Lire `CodSpeedHQ/codspeed` (repo CLI) pour voir comment ces instruments sont implémentés.
  - Pratique : `codspeed exec -- ./ton-binaire` en local vs `--mode walltime`, comprendre pourquoi walltime a besoin d'un runner dédié pour être stable.

---

## J5-J6 — eBPF : les bases (le vrai nouveau sujet)

C'est le sujet le plus neuf pour toi (absent de tes projets 42 actuels) et celui que ton mentor a mentionné en dernier point — mais comme c'est nouveau, ça mérite plus de temps réel que les fondamentaux Linux.

- **J5 — Concepts**
  - Qu'est-ce qu'un programme eBPF (bytecode vérifié par le kernel verifier, attaché à un hook : syscall/kprobe/uprobe/tracepoint), les maps eBPF pour faire remonter des données en userspace, pourquoi c'est plus sûr qu'un module kernel classique.
  - Ressource : article Polar Signals "DWARF-based Stack Walking Using eBPF" — bon exemple concret des limites d'eBPF pour l'unwinding.

- **J6 — Pratique**
  - Un tutoriel "hello world eBPF" (bpftrace ou libbpf-rs) pour tracer les `openat` d'un process. Objectif : avoir vraiment écrit/lancé un programme eBPF, pas juste en avoir lu la théorie.

---

## J7-J8 — Stack unwinding : ce qui est vraiment nouveau (DWARF/CFI)

Le frame pointer (`rbp` chaîné), tu l'as déjà manipulé en détail avec `libasm`/l'ABI x86-64 — pas la peine d'y passer du temps. Le vrai nouveau, c'est le format DWARF/CFI et la mécanique `samply`.

- **J7 — Frame pointer, en confirmation rapide**
  - Compile `playground` avec/sans `-fno-omit-frame-pointer`, compare un `samply record` sur les deux — ça doit confirmer ce que tu sais déjà de l'ABI plutôt que l'enseigner.

- **J8 — DWARF/CFI en détail (nouveau)**
  - `.eh_frame`, CFI (Call Frame Information), pourquoi c'est plus lent mais plus fiable sans frame pointer.
  - Doc à lire : [Performance Profiling and Flame Graphs](https://codspeed.io/docs/features/profiling.md).
  - Pratique : lire le sous-module `samply` du repo `codspeed`, faire un `samply record` sur `playground`, ouvrir le profil dans le Firefox Profiler UI.

---

## J9-J11 — `memtrack` (eBPF + mémoire) et intégration `krpsim`

- **J9 — `memtrack`**
  - Doc à lire : [Memory instrument](https://codspeed.io/docs/instruments/memory/index.md).
  - Lire la crate `memtrack` du repo `codspeed` — l'exemple concret cité par ton mentor pour le tracking mémoire via eBPF. Identifier les hooks utilisés (uprobes sur `malloc`/`free` probablement) et comment les données remontent au rapport.

- **J10-J11 — Intégrer CodSpeed à `krpsim`**
  - Plutôt qu'un mini-projet sur un repo jouet (`playground`), utilise ton propre projet 42 : `krpsim` (moteur de simulation à événements discrets, graphes de dépendances, scheduling, optimisation) est un bien meilleur candidat, tu en connais déjà tous les recoins algorithmiques.
  - Objectif : ajouter des benchmarks `codspeed-rust` sur les fonctions critiques (résolution du graphe de dépendances, boucle d'ordonnancement), les faire tourner en CI via GitHub Actions, et profiler avec `samply` pour voir où le temps est réellement passé.
  - C'est l'exercice qui rapproche le plus ta prépa d'un vrai cas d'usage CodSpeed.

---

## J12-J13 — Consolidation + revue de code réel

- **J12 — Lecture de PR / issues réelles**
  - Parcourir des PRs récentes fermées sur `CodSpeedHQ/codspeed`, `codspeed-rust`, `instrument-hooks` — voir comment l'équipe raisonne sur des changements de perf/mesure. Bien plus formateur à ton niveau que de la lecture de doc générique.

- **J13 — Notes de synthèse**
  - Résumer en quelques phrases (pour toi) : où `instrument-hooks` intervient dans le cycle de vie d'un bench, quand CodSpeed a besoin de frame pointers vs DWARF, comment `memtrack` capte les allocations.

---

## J14-J19 — Marge, approfondissement libre, et jours tampon

Vu que les fondamentaux sont déjà acquis, tu as ~6 jours de marge réelle. Suggestions par ordre de valeur, à piocher selon ton appétit :

1. Continuer/finir l'intégration `krpsim` + CodSpeed si J10-J11 n'ont pas suffi.
2. Approfondir eBPF au-delà du "hello world" (ex: écrire un petit équivalent simplifié de `memtrack` sur un cas jouet).
3. Explorer `mstange/framehop` (lib Rust d'unwinding utilisée par `samply`) — pertinent vu ton niveau en Rust/ASM.
4. Piocher un chapitre ciblé dans *Systems Performance* (Brendan Gregg) sur le tracing/eBPF, en écho à J5-J9.
5. Repos GitHub personnels nettoyés et documentés (`krpsim` notamment, si tu comptes le montrer).

## J20 — Révision + questions pour l'équipe

- Relire tes notes, identifier 3-5 questions précises à poser le premier jour (ex : "comment `instrument-hooks` distingue les instruments au runtime ?", "pourquoi walltime nécessite un runner dédié ?", "comment `memtrack` gère les faux positifs de leak ?").
- Repos GitHub bien nettoyés et poussés, prêts à montrer si besoin.

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

- **KFS (kfs-1, kfs-2, kfs-3) en Rust** — x86_32, Multiboot, VGA, Shell, GDT, Segmentation, Paging, IDT. `kfs-1` est fait, tu es sur la suite. Lien réel avec le poste : GDT/Segmentation/Paging = la mémoire virtuelle vue "par en dessous", en écho direct à ce que tu maîtrises déjà côté userspace via `ft_linux`. Pas urgent avant le 31 août, très rentable comme fil de fond sur plusieurs mois.
- **Operating Systems: Three Easy Pieces** — passe en mode référence plutôt que lecture séquentielle : ouvre le chapitre qui correspond à ce que tu creuses ce jour-là.
- **Systems Performance: Enterprise and the Cloud** (Brendan Gregg) — très pertinent pour un rôle de perf engineering. Cible les chapitres CPU, mémoire, et tracing/eBPF en priorité (en écho direct à J5-J9 de la Partie 1).
- **The Rust Programming Language** — continue à ton rythme, utile au quotidien sur les repos CodSpeed (et sur `kfs` en Rust).
- **Low-Level Programming (Zhirkov), Code (Petzold), Hacking: The Art of Exploitation** — déjà dans tes lectures actuelles, cohérents avec la culture bas-niveau du poste ; pas besoin de les prioriser spécifiquement pour CodSpeed, mais ils nourrissent la même direction que le Tier 1 (ASM, ABI, exploitation mémoire).

### Tier 3 — Culture générale, à picorer sans pression

- **A Philosophy of Software Design** — bon livre, mais assez déconnecté du sujet précis du stage (design logiciel général vs perf/systèmes). À lire quand tu as un moment mort, sans objectif de vitesse.

### Item à clarifier

- **"( More )"** — c'était pour ce que le Systems Engineer allait potentiellement ajouter ; à compléter quand tu as plus de détails de sa part.

## Principe général (suivi long terme)

Comme en pré-stage : privilégie toujours l'exercice pratique sur la lecture longue. Pour les tiers 2 et 3, la règle est "lire un chapitre pertinent quand un vrai problème te pousse à le lire", pas "avancer le pourcentage du livre". Le Tier 1 doit rester vivant tout le stage — c'est ce qui compte le plus pour la suite (CDI).

