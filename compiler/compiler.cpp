#include "compiler.hpp"
#include <shaderc/shaderc.hpp>
#include <path.hpp>
#include "util.hpp"
#include "filesystem.hpp"

using namespace std;

namespace Granite
{

Stage GLSLCompiler::stage_from_path(const std::string &path)
{
	auto ext = Path::ext(path);
	if (ext == "vert")
		return Stage::Vertex;
	else if (ext == "tesc")
		return Stage::TessControl;
	else if (ext == "tese")
		return Stage::TessEvaluation;
	else if (ext == "geom")
		return Stage::Geometry;
	else if (ext == "frag")
		return Stage::Fragment;
	else if (ext == "comp")
		return Stage::Compute;
	else
		throw logic_error("invalid extension");
}

void GLSLCompiler::set_source_from_file(const string &path)
{
	auto file = Filesystem::get().open(path);
	if (!file)
		throw runtime_error("file open");
	auto *mapped = static_cast<const char *>(file->map());
	if (!mapped)
		throw runtime_error("file map");
	source = string(mapped, mapped + file->get_size());

	source_path = path;
	stage = stage_from_path(path);
}

bool GLSLCompiler::parse_variants(const string &source, const string &path)
{
	auto lines = Util::split(source, "\n");

	unsigned line_index = 0;
	for (auto &line : lines)
	{
		if (line.find("#include \"") == 0)
		{
			auto include_path = line.substr(10);
			if (!include_path.empty() && include_path.back() == '"')
				include_path.pop_back();

			include_path = Path::relpath(path, include_path);
			auto file = Filesystem::get().open(include_path);
			if (!file)
			{
				LOGE("Failed to include GLSL file: %s\n", include_path.c_str());
				return false;
			}

			auto *mapped = static_cast<const char *>(file->map());
			if (!mapped)
				return false;
			size_t size = file->get_size();

			preprocessed_source += Util::join("#line ", 1, " \"", include_path, "\"\n");
			if (!parse_variants({ mapped, mapped + size }, include_path))
				return false;
			preprocessed_source += Util::join("#line ", line_index + 2, " \"", path, "\"\n");

			dependencies.insert(include_path);
		}
		else
		{
			preprocessed_source += line;
			preprocessed_source += '\n';

			auto first_non_space = line.find_first_not_of(' ');
			if (first_non_space != string::npos && line[first_non_space] == '#')
			{
				auto keywords = Util::split(line.substr(first_non_space + 1), " ");
				if (keywords.size() == 1)
				{
					auto &word = keywords.front();
					if (word == "endif")
						preprocessed_source += Util::join("#line ", line_index + 2, " \"", path, "\"\n");
				}
			}
		}

		line_index++;
	}
	return true;
}

bool GLSLCompiler::preprocess()
{
	preprocessed_source.clear();
	return parse_variants(source, source_path);
}

vector<uint32_t> GLSLCompiler::compile(const vector<pair<string, int>> *defines)
{
	shaderc::Compiler compiler;
	shaderc::CompileOptions options;
	if (preprocessed_source.empty())
	{
		LOGE("Need to preprocess source first.\n");
		return {};
	}

	if (defines)
		for (auto &define : *defines)
			options.AddMacroDefinition(define.first, to_string(define.second));

	options.SetGenerateDebugInfo();
	options.SetOptimizationLevel(shaderc_optimization_level_zero);
	options.SetTargetEnvironment(shaderc_target_env_vulkan, 1);
	options.SetSourceLanguage(shaderc_source_language_glsl);

	shaderc_shader_kind kind;
	switch (stage)
	{
	case Stage::Vertex:
		kind = shaderc_glsl_vertex_shader;
		break;

	case Stage::TessControl:
		kind = shaderc_glsl_tess_control_shader;
		break;

	case Stage::TessEvaluation:
		kind = shaderc_glsl_tess_evaluation_shader;
		break;

	case Stage::Geometry:
		kind = shaderc_glsl_geometry_shader;
		break;

	case Stage::Fragment:
		kind = shaderc_glsl_fragment_shader;
		break;

	case Stage::Compute:
		kind = shaderc_glsl_compute_shader;
		break;
	}
	shaderc::SpvCompilationResult result = compiler.CompileGlslToSpv(preprocessed_source, kind, source_path.c_str(), options);

	error_message.clear();
	if (result.GetCompilationStatus() != shaderc_compilation_status_success)
	{
		error_message = result.GetErrorMessage();
		return {};
	}

	return { result.cbegin(), result.cend() };
}
}