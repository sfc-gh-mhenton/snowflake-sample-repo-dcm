import yaml
import sys
import os

VALID_TOOL_TYPES = [
    'cortex_analyst_text_to_sql',
    'cortex_search',
    'data_to_chart',
    'custom_tool',
    'web_search'
]

def validate_agent(filepath):
    with open(filepath, 'r') as f:
        spec = yaml.safe_load(f)

    errors = []

    if spec is None:
        errors.append("File is empty or invalid YAML")
        return errors

    if 'tools' in spec:
        for i, tool in enumerate(spec['tools']):
            tool_spec = tool.get('tool_spec', {})
            tool_type = tool_spec.get('type')
            if tool_type not in VALID_TOOL_TYPES:
                errors.append(f"Tool [{i}]: invalid type '{tool_type}'. Must be one of: {VALID_TOOL_TYPES}")
            if not tool_spec.get('name'):
                errors.append(f"Tool [{i}]: missing 'name'")
            if not tool_spec.get('description'):
                errors.append(f"Tool [{i}]: missing 'description'")

    if 'tool_resources' in spec and 'tools' in spec:
        tool_names = set()
        for t in spec['tools']:
            ts = t.get('tool_spec', {})
            if ts.get('name'):
                tool_names.add(ts['name'])
        for resource_name in spec['tool_resources']:
            if resource_name not in tool_names:
                errors.append(f"tool_resources.{resource_name}: no matching tool defined")

    if 'instructions' in spec:
        instr = spec['instructions']
        if not instr.get('response'):
            errors.append("instructions.response is empty or missing")
        if not instr.get('orchestration'):
            errors.append("instructions.orchestration is empty or missing")

    if 'orchestration' in spec:
        budget = spec['orchestration'].get('budget', {})
        seconds = budget.get('seconds', 30)
        if seconds > 120:
            errors.append(f"orchestration.budget.seconds={seconds} exceeds max (120)")

    return errors


def main():
    if len(sys.argv) < 2:
        print("Usage: python validate_agent_spec.py <agents_directory>")
        sys.exit(1)

    base_dir = sys.argv[1]
    all_errors = {}
    files_checked = 0

    for root, dirs, files in os.walk(base_dir):
        for f in files:
            if f == 'agent_spec.yaml' or f == 'agent_spec.yml' or f == 'agent.yaml' or f == 'agent.yml':
                path = os.path.join(root, f)
                files_checked += 1
                errs = validate_agent(path)
                if errs:
                    all_errors[path] = errs

    if files_checked == 0:
        print(f"WARNING: No agent.yaml files found under {base_dir}/")
        sys.exit(0)

    if all_errors:
        print(f"FAILED: {len(all_errors)} file(s) with errors:\n")
        for path, errs in all_errors.items():
            print(f"  {path}:")
            for e in errs:
                print(f"    - {e}")
        sys.exit(1)
    else:
        print(f"OK: {files_checked} agent spec(s) validated successfully.")


if __name__ == '__main__':
    main()
