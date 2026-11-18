import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const skillDir = 'C:/Users/Admin/.codex/plugins/cache/openai-primary-runtime/presentations/26.1112.11217/skills/Presentations';
const workspaceDir = 'C:/Users/Admin/StudioProjects/Voya';
const templatePath = 'D:/Download/Poster Template A1 size (Project 2).pptx';
const finalPath = path.join(workspaceDir, 'poster_output', 'Voya_Group_Trip_A1_Poster_Content_Only.pptx');
const stagingDir = path.join(workspaceDir, '.poster_build', '.codex-finalizer');
const candidatePath = path.join(stagingDir, 'candidate.pptx');
await fs.mkdir(stagingDir, { recursive: true });
await fs.mkdir(path.dirname(finalPath), { recursive: true });
await fs.copyFile(path.join(workspaceDir, '.poster_build', 'voya-a1-content-only-draft.pptx'), candidatePath);

const { finalizePresentation } = await import(pathToFileURL(path.join(skillDir, 'container_tools/artifact_tool_utils.mjs')).href);
process.env.RUNTIME_NODE_MODULES = 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-737-0_26.1112.737.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules';
const result = await finalizePresentation({
  workspaceDir,
  candidatePath,
  finalPath,
  pythonExecutable: 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-737-0_26.1112.737.0_x64__3k8sg7r9htsxt/dependencies/python/python.exe',
  integrityValidatorPath: path.join(skillDir, 'container_tools/inspect_presentation_package_integrity.py'),
  layoutValidatorPath: path.join(skillDir, 'container_tools/inspect_presentation_layout_geometry.py'),
  layoutArgs: ['--expected-slide-size-emu', '21396325,30267275', '--validate-bullet-geometry', '--validate-heading-fit'],
  explicitTotalSlideCount: 1,
  requiredNativeTableOwnerSlides: [],
  requiredNativeChartOwnerSlides: [],
  materializeLiteralChartWorkbooks: true,
  fontPolicy: {
    basis: 'reference',
    families: ['Arial', 'Gill Sans MT', 'Times New Roman'],
    referencePath: templatePath,
    referenceSha256: 'c8d0a1c5b6859d8cad574b739c06daa487657a184053a4af56103fa0bf2cf49f',
  },
  verifyArtifactToolImport: true,
  receiptPath: path.join(stagingDir, 'Voya_Group_Trip_A1_Poster_Content_Only.validation.json'),
});
console.log(JSON.stringify(result, null, 2));
