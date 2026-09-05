import { spawn } from "node:child_process";
import { access, mkdir, readFile, realpath, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const STATUSES = ["active", "paused", "done", "archived"] as const;
type ProjectStatus = (typeof STATUSES)[number];

interface ResearchProject {
	name: string;
	path: string;
	topicSlug: string;
	goal: string;
	status: ProjectStatus;
	createdAt: string;
	updatedAt: string;
}

interface ProjectRegistry {
	version: 1;
	projects: ResearchProject[];
}

const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const registryPath = join(agentDir, "research-projects.json");

function emptyRegistry(): ProjectRegistry {
	return { version: 1, projects: [] };
}

function isStatus(value: string): value is ProjectStatus {
	return (STATUSES as readonly string[]).includes(value);
}

async function loadRegistry(): Promise<ProjectRegistry> {
	try {
		const parsed = JSON.parse(await readFile(registryPath, "utf8")) as Partial<ProjectRegistry>;
		if (parsed.version !== 1 || !Array.isArray(parsed.projects)) throw new Error("unsupported format");
		return {
			version: 1,
			projects: parsed.projects.filter((project): project is ResearchProject =>
				Boolean(project && typeof project.name === "string" && typeof project.path === "string" &&
					typeof project.topicSlug === "string" && typeof project.goal === "string" &&
					typeof project.createdAt === "string" && typeof project.updatedAt === "string" &&
					isStatus(String(project.status))),
			),
		};
	} catch (error: unknown) {
		if ((error as NodeJS.ErrnoException).code === "ENOENT") return emptyRegistry();
		throw new Error(`Cannot read ${registryPath}: ${error instanceof Error ? error.message : String(error)}`);
	}
}

async function saveRegistry(registry: ProjectRegistry): Promise<void> {
	await mkdir(dirname(registryPath), { recursive: true });
	const temporaryPath = `${registryPath}.${process.pid}.tmp`;
	await writeFile(temporaryPath, `${JSON.stringify(registry, null, 2)}\n`, "utf8");
	await rename(temporaryPath, registryPath);
}

async function canonicalDirectory(path: string): Promise<string> {
	const canonical = await realpath(resolve(path));
	await access(canonical);
	return canonical;
}

async function registerProject(input: {
	path: string;
	name?: string;
	topicSlug: string;
	goal: string;
	status?: ProjectStatus;
}): Promise<ResearchProject> {
	const projectPath = await canonicalDirectory(input.path);
	const now = new Date().toISOString();
	const registry = await loadRegistry();
	const existing = registry.projects.find((project) => project.path === projectPath);
	const project: ResearchProject = {
		name: input.name?.trim() || existing?.name || basename(projectPath),
		path: projectPath,
		topicSlug: input.topicSlug.trim(),
		goal: input.goal.trim(),
		status: input.status ?? existing?.status ?? "active",
		createdAt: existing?.createdAt ?? now,
		updatedAt: now,
	};
	if (!project.topicSlug || !project.goal) throw new Error("topicSlug and goal are required");
	if (existing) Object.assign(existing, project);
	else registry.projects.push(project);
	await saveRegistry(registry);
	return project;
}

async function updateStatus(projectPath: string, status: ProjectStatus): Promise<ResearchProject | undefined> {
	const canonical = await canonicalDirectory(projectPath);
	const registry = await loadRegistry();
	const project = registry.projects.find((entry) => entry.path === canonical);
	if (!project) return undefined;
	project.status = status;
	project.updatedAt = new Date().toISOString();
	await saveRegistry(registry);
	return project;
}

function projectLabel(project: ResearchProject): string {
	return `[${project.status}] ${project.name} — ${project.goal} (${project.path})`;
}

async function chooseProject(ctx: ExtensionContext, projects: ResearchProject[]): Promise<ResearchProject | undefined> {
	if (!ctx.hasUI || projects.length === 0) return undefined;
	const options = projects.map(projectLabel);
	const chosen = await ctx.ui.select("Research projects", options);
	return chosen ? projects[options.indexOf(chosen)] : undefined;
}

function launchProject(ctx: ExtensionContext, project: ResearchProject): void {
	try {
		const child = spawn(process.execPath, [process.argv[1], "--continue"], {
			cwd: project.path,
			env: process.env,
			stdio: "inherit",
			detached: true,
		});
		child.unref();
		ctx.ui.notify(`Opening ${project.name} in ${project.path}`, "info");
		ctx.shutdown();
	} catch (error) {
		ctx.ui.notify(`Could not open ${project.name}: ${error instanceof Error ? error.message : String(error)}`, "error");
	}
}

function findProjects(projects: ResearchProject[], query: string): ResearchProject[] {
	const normalized = query.trim().toLowerCase();
	if (!normalized) return [];
	const exact = projects.filter((project) =>
		[project.name, project.topicSlug, project.path, basename(project.path)].some((value) => value.toLowerCase() === normalized),
	);
	return exact.length ? exact : projects.filter((project) =>
		[project.name, project.topicSlug, project.path, basename(project.path), project.goal]
			.some((value) => value.toLowerCase().includes(normalized)),
	);
}

async function openByQuery(ctx: ExtensionContext, query: string): Promise<boolean> {
	const matches = findProjects((await loadRegistry()).projects.filter((project) => project.status !== "archived"), query);
	if (matches.length === 0) return false;
	const project = matches.length === 1 ? matches[0] : await chooseProject(ctx, matches);
	if (project) launchProject(ctx, project);
	return true;
}

export default function researchProjectManager(pi: ExtensionAPI) {
	pi.registerCommand("project", {
		description: "Open, list, or update a registered research project",
		handler: async (args, ctx) => {
			const command = args.trim();
			const statusMatch = command.match(/^(?:status\s+)?(active|paused|done|archived)$/i);
			if (statusMatch) {
				const project = await updateStatus(ctx.cwd, statusMatch[1].toLowerCase() as ProjectStatus);
				ctx.ui.notify(project
					? `${project.name} is now ${project.status}.`
					: "The current directory is not a registered research project.", project ? "info" : "warning");
				return;
			}
			if (command === "archive") {
				const project = await updateStatus(ctx.cwd, "archived");
				ctx.ui.notify(project ? `${project.name} is now archived.` : "The current directory is not registered.", project ? "info" : "warning");
				return;
			}

			const registry = await loadRegistry();
			if (command && command !== "all") {
				const opened = await openByQuery(ctx, command);
				if (!opened) ctx.ui.notify(`No registered project matches “${command}”.`, "warning");
				return;
			}

			let projects = command === "all"
				? registry.projects
				: registry.projects.filter((project) => project.status === "active" || project.status === "paused");
			const showOther = "Show done and archived projects…";
			const options = [...projects.map(projectLabel), showOther];
			const selected = ctx.hasUI ? await ctx.ui.select("Research projects", options) : undefined;
			if (!selected) return;
			if (selected === showOther) {
				projects = registry.projects;
				const project = await chooseProject(ctx, projects);
				if (project) launchProject(ctx, project);
				return;
			}
			const project = projects[options.indexOf(selected)];
			if (project) launchProject(ctx, project);
		},
	});

	pi.registerTool({
		name: "register_research_project",
		label: "Register Research Project",
		description: "Register or update a scaffolded research project so it appears in /project. Use after creating a research project or when correcting its metadata.",
		parameters: Type.Object({
			path: Type.String({ description: "Absolute path to the research project root" }),
			name: Type.Optional(Type.String({ description: "Short display name" })),
			topicSlug: Type.String({ description: "The project's kebab-case domain-skill slug" }),
			goal: Type.String({ description: "The project goal in the user's words" }),
			status: Type.Optional(Type.Union(STATUSES.map((status) => Type.Literal(status)))),
		}),
		async execute(_toolCallId, params) {
			try {
				const project = await registerProject(params);
				return { content: [{ type: "text", text: `Registered ${project.name} as ${project.status}: ${project.path}` }], details: project };
			} catch (error) {
				return { content: [{ type: "text", text: `Could not register research project: ${error instanceof Error ? error.message : String(error)}` }], details: {}, isError: true };
			}
		},
	});

	pi.registerTool({
		name: "set_research_project_status",
		label: "Set Research Project Status",
		description: "Set a registered research project's lifecycle status to active, paused, done, or archived.",
		parameters: Type.Object({
			path: Type.String({ description: "Absolute path to the registered research project root" }),
			status: Type.Union(STATUSES.map((status) => Type.Literal(status))),
		}),
		async execute(_toolCallId, params) {
			try {
				const project = await updateStatus(params.path, params.status);
				return project
					? { content: [{ type: "text", text: `${project.name} is now ${project.status}.` }], details: project }
					: { content: [{ type: "text", text: "That directory is not a registered research project." }], details: {}, isError: true };
			} catch (error) {
				return { content: [{ type: "text", text: `Could not update project status: ${error instanceof Error ? error.message : String(error)}` }], details: {}, isError: true };
			}
		},
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension") return;
		const match = event.text.trim().match(/^(?:please\s+)?(?:(?:i\s+(?:want|would\s+like)\s+to\s+)?work\s+on|open|switch(?:\s+to)?|resume)\s+(?:my\s+)?(?:research\s+)?project\s+(.+?)[.!]?$/i);
		if (!match) return;
		return (await openByQuery(ctx, match[1])) ? { action: "handled" } : undefined;
	});
}
