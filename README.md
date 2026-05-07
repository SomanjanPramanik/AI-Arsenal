\# 🚀 AI Arsenal 



<div align="center">

&#x20; <img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge\&logo=powershell\&logoColor=white" />

&#x20; <img src="https://img.shields.io/badge/Ollama-Local\_AI-lightgrey?style=for-the-badge" />

&#x20; <img src="https://img.shields.io/badge/Claude\_3.5-Anthropic-D97757?style=for-the-badge" />

&#x20; <img src="https://img.shields.io/badge/GPT--4o-OpenAI-412991?style=for-the-badge\&logo=openai\&logoColor=white" />

</div>



<br>



\*\*AI Arsenal\*\* is a powerful, terminal-based AI assistant and workflow automation suite built entirely in Windows PowerShell. Designed specifically for Software Developers and SDETs, it integrates advanced local and cloud-based LLMs directly into your command line to accelerate coding, testing, and daily workflows.



\---
## 📁 Project Structure
```
AI-Arsenal/
├── src/
│   └── ai-arsenal.ps1        ← the main script — paste into $PROFILE
├── testing/
│   └── Test-AIArsenal.ps1    ← automated test runner (95 assertions)
└── README.md
```
\---

\## ✨ Core Features



\### 🤖 Dual AI Engine

\* \*\*Local Mode:\*\* Full privacy and offline capabilities using \*\*Ollama\*\* (Gemma, Mistral). Cascading fallbacks ensure a response even under heavy RAM pressure.

\* \*\*Cloud Mode:\*\* High-fidelity API integration with \*\*Anthropic Claude 3.5 Sonnet\*\* and \*\*OpenAI GPT-4o\*\* for complex reasoning and multimodal vision tasks.



\### 🧪 SDET \& Code Quality Automation

\* `ai-qa`: Instantly generate production-ready Cucumber feature files, Step Definitions, and TestNG boilerplate from plain English descriptions.

\* `ai-test`: Auto-generate comprehensive unit tests covering happy paths, edge cases, and exceptions.

\* `ai-debug` \& `ai-fix`: AI-driven code analysis that automatically finds bugs, explains them, and overwrites your file with a backed-up, corrected version.

\* `ai-review`: Senior-level code reviews checking for SOLID principles, security, and test coverage gaps.



\### 🐙 Automated Git Workflow

\* `ai-diff`: Senior review of your current staged and unstaged Git changes.

\* `ai-commit`: Automatically generate Conventional Commit messages based on your staged diff.

\* `ai-git-push`: All-in-one macro to stage, generate a commit message, commit, and push in a single keystroke.



\### 👁️ Multimodal \& File Parsing

\* `ai-img` \& `ai-ocr`: Extract text, analyze diagrams, and read UI screenshots using Vision models or local EasyOCR.

\* `ai-sum` \& `ai-folder`: Batch-analyze entire directories of code or summarize PDFs, Word docs, and plain text files directly in the terminal.



\### 🧠 Interview Prep \& Productivity

\* `ai-mock`: Full 5-question interactive mock interviews with a final HR/Technical grading rubric.

\* `ai-timer`: Terminal-based Pomodoro focus timer with a live progress bar and session logging.

\* `ai-snippet`: Save, retrieve, and manage reusable code snippets straight to your clipboard.



\---



\## 🚀 Installation (60 Seconds)



1\. Open PowerShell as a normal user.

2\. Open your PowerShell profile by running: `notepad $PROFILE`

3\. Paste the contents of `ai-arsenal.ps1` into the file, save, and close.

4\. Restart PowerShell.

5\. Type `ai-setup` to launch the interactive configuration wizard.

6\. Type `ai-help` to see the full command reference.



\## 🛠️ Requirements

\* Windows 10/11

\* PowerShell 5.1 or 7+

\* \*(Optional)\* \[Ollama](https://ollama.com/) for Local AI execution

\* \*(Optional)\* Python 3.8+ (for OCR and local PDF parsing)

\---

## 🧪 Running the Tests

Load your profile first, then run the test runner from the `testing/` folder:

```powershell
. $PROFILE
.\testing\Test-AIArsenal.ps1
```

Optional flags:
- `-Verbose` — show passing tests too
- `-Category Internal` — only test `_SC-*` engine functions
- `-Category Public` — only test `ai-*` commands

\---

\*Developed by Somanjan Pramanik\*

