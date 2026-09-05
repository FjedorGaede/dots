/**
 * Questionnaire Tool - Unified tool for asking single or multiple questions
 *
 * Single question: simple options list
 * Multiple questions: tab bar navigation between questions
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, truncateToWidth } from "@earendil-works/pi-tui";
import { Type } from "typebox";

// Types
interface QuestionOption {
	value: string;
	label: string;
	description?: string;
}

type RenderOption = QuestionOption & { isOther?: boolean };

interface Question {
	id: string;
	label: string;
	prompt: string;
	options: QuestionOption[];
	allowOther: boolean;
	multiSelect?: boolean; // allow multiple selections via Space
	freeText?: boolean;    // no options, just a text input
}

interface Answer {
	id: string;
	value: string | string[]; // string[] for multiSelect
	label: string | string[];
	wasCustom: boolean;
	index?: number | number[];
}

interface QuestionnaireResult {
	questions: Question[];
	answers: Answer[];
	cancelled: boolean;
}

// Schema
const QuestionOptionSchema = Type.Object({
	value: Type.String({ description: "The value returned when selected" }),
	label: Type.String({ description: "Display label for the option" }),
	description: Type.Optional(Type.String({ description: "Optional description shown below label" })),
});

const QuestionSchema = Type.Object({
	id: Type.String({ description: "Unique identifier for this question" }),
	label: Type.Optional(
		Type.String({
			description: "Short contextual label for tab bar, e.g. 'Scope', 'Priority' (defaults to Q1, Q2)",
		}),
	),
	prompt: Type.String({ description: "The full question text to display" }),
	options: Type.Optional(Type.Array(QuestionOptionSchema, { description: "Available options to choose from" })),
	allowOther: Type.Optional(Type.Boolean({ description: "Allow 'Type something' option (default: true)" })),
	multiSelect: Type.Optional(Type.Boolean({ description: "Allow selecting multiple options with Space (default: false)" })),
	freeText: Type.Optional(Type.Boolean({ description: "No options, just a free-text input field (default: false)" })),
});

const QuestionnaireParams = Type.Object({
	questions: Type.Array(QuestionSchema, { description: "Questions to ask the user" }),
});

function errorResult(
	message: string,
	questions: Question[] = [],
): { content: { type: "text"; text: string }[]; details: QuestionnaireResult } {
	return {
		content: [{ type: "text", text: message }],
		details: { questions, answers: [], cancelled: true },
	};
}

export default function questionnaire(pi: ExtensionAPI) {
	pi.registerTool({
		name: "questionnaire",
		label: "Questionnaire",
		description:
			"Ask the user one or more questions. Use for clarifying requirements, getting preferences, or confirming decisions. Supports three question types: single-select (options list, Enter to pick), multi-select (checkbox list, Space to toggle + Enter to confirm), and free-text (inline editor). For multiple questions, shows a tab-based interface with ←→ navigation.",
		parameters: QuestionnaireParams,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) {
				return errorResult("Error: UI not available (running in non-interactive mode)");
			}
			if (params.questions.length === 0) {
				return errorResult("Error: No questions provided");
			}

			// Normalize questions with defaults
			const questions: Question[] = params.questions.map((q, i) => ({
				...q,
				options: q.options ?? [],
				label: q.label || `Q${i + 1}`,
				allowOther: q.freeText ? false : (q.allowOther !== false),
				multiSelect: q.multiSelect === true,
				freeText: q.freeText === true,
			}));

			const isMulti = questions.length > 1;
			const totalTabs = questions.length + 1; // questions + Submit

			const result = await ctx.ui.custom<QuestionnaireResult>((tui, theme, _kb, done) => {
				// State
				let currentTab = 0;
				let optionIndex = 0;
				let inputMode = false;
				let inputQuestionId: string | null = null;
				let cachedLines: string[] | undefined;
				const answers = new Map<string, Answer>();
				// multiSelect: tracks which option indices are checked per question id
				const multiChecked = new Map<string, Set<number>>();

				// Editor for "Type something" option
				const editorTheme: EditorTheme = {
					borderColor: (s) => theme.fg("accent", s),
					selectList: {
						selectedPrefix: (t) => theme.fg("accent", t),
						selectedText: (t) => theme.fg("accent", t),
						description: (t) => theme.fg("muted", t),
						scrollInfo: (t) => theme.fg("dim", t),
						noMatch: (t) => theme.fg("warning", t),
					},
				};
				const editor = new Editor(tui, editorTheme);

				// Helpers
				function refresh() {
					cachedLines = undefined;
					tui.requestRender();
				}

				function submit(cancelled: boolean) {
					done({ questions, answers: Array.from(answers.values()), cancelled });
				}

				function currentQuestion(): Question | undefined {
					return questions[currentTab];
				}

				function currentOptions(): RenderOption[] {
					const q = currentQuestion();
					if (!q) return [];
					const opts: RenderOption[] = [...q.options];
					if (q.allowOther) {
						opts.push({ value: "__other__", label: "Type something.", isOther: true });
					}
					return opts;
				}

				function allAnswered(): boolean {
					return questions.every((q) => answers.has(q.id));
				}

				function advanceAfterAnswer() {
					if (!isMulti) {
						submit(false);
						return;
					}
					if (currentTab < questions.length - 1) {
						currentTab++;
					} else {
						currentTab = questions.length; // Submit tab
					}
					optionIndex = 0;
					refresh();
				}

				function saveAnswer(questionId: string, value: string, label: string, wasCustom: boolean, index?: number) {
					answers.set(questionId, { id: questionId, value, label, wasCustom, index });
				}

				function saveMultiAnswer(q: Question) {
					const checked = multiChecked.get(q.id) ?? new Set<number>();
					const opts = currentOptions();
					const sortedIndices = [...checked].sort((a, b) => a - b);
					const values = sortedIndices.map((i) => opts[i].value);
					const labels = sortedIndices.map((i) => opts[i].label);
					answers.set(q.id, { id: q.id, value: values, label: labels, wasCustom: false, index: sortedIndices.map((i) => i + 1) as any });
				}

				// Editor submit callback
				editor.onSubmit = (value) => {
					if (!inputQuestionId) return;
					const trimmed = value.trim() || "(no response)";
					saveAnswer(inputQuestionId, trimmed, trimmed, true);
					inputMode = false;
					inputQuestionId = null;
					editor.setText("");
					advanceAfterAnswer();
				};

				function handleInput(data: string) {
					// Input mode: route to editor
					if (inputMode) {
						if (matchesKey(data, Key.escape)) {
							inputMode = false;
							inputQuestionId = null;
							editor.setText("");
							refresh();
							return;
						}
						editor.handleInput(data);
						refresh();
						return;
					}

					const q = currentQuestion();
					const opts = currentOptions();

					// Tab navigation (multi-question only)
					if (isMulti) {
						if (matchesKey(data, Key.tab) || matchesKey(data, Key.right)) {
							currentTab = (currentTab + 1) % totalTabs;
							optionIndex = 0;
							refresh();
							return;
						}
						if (matchesKey(data, Key.shift("tab")) || matchesKey(data, Key.left)) {
							currentTab = (currentTab - 1 + totalTabs) % totalTabs;
							optionIndex = 0;
							refresh();
							return;
						}
					}

					// Submit tab
					if (currentTab === questions.length) {
						if (matchesKey(data, Key.enter) && allAnswered()) {
							submit(false);
						} else if (matchesKey(data, Key.escape)) {
							submit(true);
						}
						return;
					}

					// Free-text question: any key activates the editor
					if (q?.freeText) {
						if (matchesKey(data, Key.escape)) { submit(true); return; }
						inputMode = true;
						inputQuestionId = q.id;
						editor.setText("");
						editor.handleInput(data);
						refresh();
						return;
					}

					// Option navigation
					if (matchesKey(data, Key.up)) {
						optionIndex = Math.max(0, optionIndex - 1);
						refresh();
						return;
					}
					if (matchesKey(data, Key.down)) {
						optionIndex = Math.min(opts.length - 1, optionIndex + 1);
						refresh();
						return;
					}

					// Multi-select: Space toggles, Enter confirms
					if (q?.multiSelect) {
						if (data === " ") {
							const opt = opts[optionIndex];
							if (opt?.isOther) {
								inputMode = true;
								inputQuestionId = q.id;
								editor.setText("");
								refresh();
								return;
							}
							if (!multiChecked.has(q.id)) multiChecked.set(q.id, new Set());
							const checked = multiChecked.get(q.id)!;
							if (checked.has(optionIndex)) { checked.delete(optionIndex); }
							else { checked.add(optionIndex); }
							refresh();
							return;
						}
						if (matchesKey(data, Key.enter) && q) {
							const checked = multiChecked.get(q.id) ?? new Set();
							if (checked.size === 0) return; // nothing checked yet
							saveMultiAnswer(q);
							advanceAfterAnswer();
							return;
						}
						if (matchesKey(data, Key.escape)) { submit(true); }
						return;
					}

					// Single-select: Enter selects
					if (matchesKey(data, Key.enter) && q) {
						const opt = opts[optionIndex];
						if (opt.isOther) {
							inputMode = true;
							inputQuestionId = q.id;
							editor.setText("");
							refresh();
							return;
						}
						saveAnswer(q.id, opt.value, opt.label, false, optionIndex + 1);
						advanceAfterAnswer();
						return;
					}

					// Cancel
					if (matchesKey(data, Key.escape)) {
						submit(true);
					}
				}

				function render(width: number): string[] {
					if (cachedLines) return cachedLines;

					const lines: string[] = [];
					const q = currentQuestion();
					const opts = currentOptions();

					// Helper to add truncated line
					const add = (s: string) => lines.push(truncateToWidth(s, width));

					add(theme.fg("accent", "─".repeat(width)));

					// Tab bar (multi-question only)
					if (isMulti) {
						const tabs: string[] = ["← "];
						for (let i = 0; i < questions.length; i++) {
							const isActive = i === currentTab;
							const isAnswered = answers.has(questions[i].id);
							const lbl = questions[i].label;
							const box = isAnswered ? "■" : "□";
							const color = isAnswered ? "success" : "muted";
							const text = ` ${box} ${lbl} `;
							const styled = isActive ? theme.bg("selectedBg", theme.fg("text", text)) : theme.fg(color, text);
							tabs.push(`${styled} `);
						}
						const canSubmit = allAnswered();
						const isSubmitTab = currentTab === questions.length;
						const submitText = " ✓ Submit ";
						const submitStyled = isSubmitTab
							? theme.bg("selectedBg", theme.fg("text", submitText))
							: theme.fg(canSubmit ? "success" : "dim", submitText);
						tabs.push(`${submitStyled} →`);
						add(` ${tabs.join("")}`);
						lines.push("");
					}

					// Helper to render options list
					function renderOptions() {
						const checked = q?.multiSelect ? (multiChecked.get(q.id) ?? new Set<number>()) : new Set<number>();
						for (let i = 0; i < opts.length; i++) {
							const opt = opts[i];
							const selected = i === optionIndex;
							const isOther = opt.isOther === true;
							const color = selected ? "accent" : "text";

							if (q?.multiSelect) {
								// Checkbox style: [✓] or [ ]
								const cursor = selected ? theme.fg("accent", ">") : " ";
								const box = isOther
									? (inputMode ? theme.fg("accent", "[✎]") : theme.fg("muted", "[ ]"))
									: (checked.has(i) ? theme.fg("success", "[✓]") : theme.fg("muted", "[ ]"));
								add(`${cursor} ${box} ${theme.fg(color, opt.label)}`);
							} else {
								// Single-select arrow style
								const prefix = selected ? theme.fg("accent", "> ") : "  ";
								if (isOther && inputMode) {
									add(prefix + theme.fg("accent", `${i + 1}. ${opt.label} ✎`));
								} else {
									add(prefix + theme.fg(color, `${i + 1}. ${opt.label}`));
								}
							}
							if (opt.description) {
								add(`     ${theme.fg("muted", opt.description)}`);
							}
						}
					}

					// Content
					if (q?.freeText && !inputMode) {
						add(theme.fg("text", ` ${q.prompt}`));
						lines.push("");
						add(theme.fg("muted", " Type your answer and press Enter"));
						lines.push("");
						add(theme.fg("dim", " (start typing to open editor)"));
					} else if (inputMode && q) {
						add(theme.fg("text", ` ${q.prompt}`));
						lines.push("");
						if (!q.freeText) {
							// Show options for reference (not for pure free-text)
							renderOptions();
							lines.push("");
						}
						add(theme.fg("muted", " Your answer:"));
						for (const line of editor.render(width - 2)) {
							add(` ${line}`);
						}
						lines.push("");
						add(theme.fg("dim", " Enter to submit • Esc to cancel"));
					} else if (currentTab === questions.length) {
						add(theme.fg("accent", theme.bold(" Ready to submit")));
						lines.push("");
						for (const question of questions) {
							const answer = answers.get(question.id);
							if (answer) {
								const prefix = answer.wasCustom ? "(wrote) " : "";
								add(`${theme.fg("muted", ` ${question.label}: `)}${theme.fg("text", prefix + answer.label)}`);
							}
						}
						lines.push("");
						if (allAnswered()) {
							add(theme.fg("success", " Press Enter to submit"));
						} else {
							const missing = questions
								.filter((q) => !answers.has(q.id))
								.map((q) => q.label)
								.join(", ");
							add(theme.fg("warning", ` Unanswered: ${missing}`));
						}
					} else if (q) {
						add(theme.fg("text", ` ${q.prompt}`));
						lines.push("");
						renderOptions();
					}

					lines.push("");
					if (!inputMode) {
						const q2 = currentQuestion();
						let help: string;
						if (q2?.freeText) {
							help = isMulti
								? " Tab/←→ navigate • start typing to answer • Esc cancel"
								: " Start typing to answer • Esc cancel";
						} else if (q2?.multiSelect) {
							help = isMulti
								? " Tab/←→ navigate • ↑↓ move • Space toggle • Enter confirm • Esc cancel"
								: " ↑↓ move • Space toggle • Enter confirm • Esc cancel";
						} else {
							help = isMulti
								? " Tab/←→ navigate • ↑↓ select • Enter confirm • Esc cancel"
								: " ↑↓ navigate • Enter select • Esc cancel";
						}
						add(theme.fg("dim", help));
					}
					add(theme.fg("accent", "─".repeat(width)));

					cachedLines = lines;
					return lines;
				}

				return {
					render,
					invalidate: () => {
						cachedLines = undefined;
					},
					handleInput,
				};
			});

			if (result.cancelled) {
				return {
					content: [{ type: "text", text: "User cancelled the questionnaire" }],
					details: result,
				};
			}

			const answerLines = result.answers.map((a) => {
				const qLabel = questions.find((q) => q.id === a.id)?.label || a.id;
				if (a.wasCustom) {
					return `${qLabel}: user wrote: ${a.label}`;
				}
				if (Array.isArray(a.label)) {
					return `${qLabel}: user selected (multi): ${a.label.join(", ")}`;
				}
				return `${qLabel}: user selected: ${a.index}. ${a.label}`;
			});

			return {
				content: [{ type: "text", text: answerLines.join("\n") }],
				details: result,
			};
		},

		renderCall(args, theme, _context) {
			const qs = (args.questions as Question[]) || [];
			const count = qs.length;
			const labels = qs.map((q) => q.label || q.id).join(", ");
			let text = theme.fg("toolTitle", theme.bold("questionnaire "));
			text += theme.fg("muted", `${count} question${count !== 1 ? "s" : ""}`);
			if (labels) {
				text += theme.fg("dim", ` (${truncateToWidth(labels, 40)})`);
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme, _context) {
			const details = result.details as QuestionnaireResult | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}
			if (details.cancelled) {
				return new Text(theme.fg("warning", "Cancelled"), 0, 0);
			}
			const lines = details.answers.map((a) => {
				if (a.wasCustom) {
					return `${theme.fg("success", "✓ ")}${theme.fg("accent", a.id)}: ${theme.fg("muted", "(wrote) ")}${a.label}`;
				}
				if (Array.isArray(a.label)) {
					return `${theme.fg("success", "✓ ")}${theme.fg("accent", a.id)}: ${a.label.join(", ")}`;
				}
				const display = a.index ? `${a.index}. ${a.label}` : a.label;
				return `${theme.fg("success", "✓ ")}${theme.fg("accent", a.id)}: ${display}`;
			});
			return new Text(lines.join("\n"), 0, 0);
		},
	});
}
