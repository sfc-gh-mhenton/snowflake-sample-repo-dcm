import yaml
import sys
import os

def resolve(env, input_file, config_path=None):
    if config_path is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, '..', 'databases.yaml')

    with open(config_path) as f:
        config = yaml.safe_load(f)

    with open(input_file) as f:
        content = f.read()

    for key, envs in config['databases'].items():
        placeholder = f'__{key}__'
        if env not in envs:
            print(f"WARNING: Environment '{env}' not found for database '{key}'", file=sys.stderr)
            continue
        resolved = envs[env]
        content = content.replace(placeholder, resolved)

    return content


def main():
    if len(sys.argv) < 3:
        print("Usage: python resolve_databases.py <environment> <input_file> [databases.yaml path]", file=sys.stderr)
        print("  environment: dev, test, or prod", file=sys.stderr)
        print("  input_file: SQL or YAML file with __PLACEHOLDER__ references", file=sys.stderr)
        sys.exit(1)

    env = sys.argv[1]
    input_file = sys.argv[2]
    config_path = sys.argv[3] if len(sys.argv) > 3 else None

    result = resolve(env, input_file, config_path)

    unresolved = []
    import re
    for match in re.finditer(r'__([A-Z_]+)__', result):
        unresolved.append(match.group(0))

    if unresolved:
        print(f"WARNING: Unresolved placeholders: {set(unresolved)}", file=sys.stderr)

    print(result)


if __name__ == '__main__':
    main()
