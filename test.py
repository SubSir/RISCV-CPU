import os
import subprocess
import shutil
import glob
from pathlib import Path

PWD = os.getcwd()

SRC_DIR = os.path.join(PWD, "src")
TESTSPACE_DIR = os.path.join(PWD, "testspace")
TESTCASE_DIR = os.path.join(PWD, "testcase")

SIM_TESTCASE_DIR = os.path.join(TESTCASE_DIR, "sim")
FPGA_TESTCASE_DIR = os.path.join(TESTCASE_DIR, "fpga")

SIM_DIR = os.path.join(PWD, "sim")


def find_v_sources(src_dir):
    return [str(f) for f in Path(src_dir).rglob("*.v")]


def run_command(command, cwd=None):
    result = subprocess.run(
        command, shell=True, cwd=cwd, capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error running command: {command}")
        print(f"Output: {result.stdout}")
        print(f"Error: {result.stderr}")
        exit(1)
    out = result.stdout
    if out == "":
        return ""
    out = out.split("IO:Return")[0]
    out = out.split("VCD info: dumpfile test.vcd opened for output.\n")[1]
    with open(os.path.join(TESTSPACE_DIR, "my.ans"), "w") as f:
        f.write(out)


def testcases():
    run_command("make", cwd=TESTCASE_DIR)


def no_testcase_name_check(name):
    if not name:
        raise ValueError(
            "name is not set. Usage: python script.py run_sim --name=your_testcase_name"
        )


def build_sim(v_sources):
    testbench_v = os.path.join(SIM_DIR, "testbench.v")
    output_file = os.path.join(TESTSPACE_DIR, "test")
    command = f'iverilog -o {output_file} {testbench_v} {" ".join(v_sources)}'
    run_command(command)


def build_sim_test(name):
    test_c = os.path.join(SIM_TESTCASE_DIR, f"*{name}*.c")
    test_data = os.path.join(SIM_TESTCASE_DIR, f"*{name}*.data")
    test_dump = os.path.join(SIM_TESTCASE_DIR, f"*{name}*.dump")
    test_ans = os.path.join(SIM_TESTCASE_DIR, f"*{name}*.ans")

    for src, dst in [
        (test_c, "test.c"),
        (test_data, "test.data"),
        (test_dump, "test.dump"),
        (test_ans, "test.ans"),
    ]:
        files = glob.glob(src)
        if files:
            shutil.copy(files[0], os.path.join(TESTSPACE_DIR, dst))


def build_fpga_test(name):
    test_c = os.path.join(FPGA_TESTCASE_DIR, f"*{name}*.c")
    test_data = os.path.join(FPGA_TESTCASE_DIR, f"*{name}*.data")
    test_dump = os.path.join(FPGA_TESTCASE_DIR, f"*{name}*.dump")

    for src, dst in [
        (test_c, "test.c"),
        (test_data, "test.data"),
        (test_dump, "test.dump"),
    ]:
        files = glob.glob(src)
        if files:
            shutil.copy(files[0], os.path.join(TESTSPACE_DIR, dst))

    test_in = os.path.join(FPGA_TESTCASE_DIR, f"*{name}*.in")
    test_ans = os.path.join(FPGA_TESTCASE_DIR, f"*{name}*.ans")

    for file in [
        os.path.join(TESTSPACE_DIR, "test.in"),
        os.path.join(TESTSPACE_DIR, "test.ans"),
    ]:
        if os.path.exists(file):
            os.remove(file)

    for src, dst in [(test_in, "test.in"), (test_ans, "test.ans")]:
        files = glob.glob(src)
        if files:
            shutil.copy(files[0], os.path.join(TESTSPACE_DIR, dst))


def run_sim():
    test_exe = "vvp " + os.path.join(TESTSPACE_DIR, "test")
    run_command(test_exe, cwd=TESTSPACE_DIR)


def run_fpga(name):
    fpga_device = "/dev/ttyUSB1"
    fpga_run_mode = "-T"  # or '-I'

    test_in = os.path.join(TESTSPACE_DIR, "test.in")
    test_data = os.path.join(TESTSPACE_DIR, "test.data")
    fpga_script = os.path.join(PWD, "fpga", "fpga")

    if os.path.exists(test_in):
        command = f"{fpga_script} {test_data} {test_in} {fpga_device} {fpga_run_mode}"
    else:
        command = f"{fpga_script} {test_data} {fpga_device} {fpga_run_mode}"

    run_command(command, cwd=TESTSPACE_DIR)


def clean():
    for file in glob.glob(os.path.join(TESTSPACE_DIR, "test*")):
        os.remove(file)


def check():
    my_ans_path = os.path.join(TESTSPACE_DIR, "my.ans")
    test_ans_path = os.path.join(TESTSPACE_DIR, "test.ans")
    with open(my_ans_path, "r") as f1, open(test_ans_path, "r") as f2:
        my_ans = f1.read()
        test_ans = f2.read()
        if my_ans == test_ans:
            print("PASS")
        else:
            print("FAIL")


def main():
    v_sources = find_v_sources(SRC_DIR)

    no_testcase_name_check("006")
    build_sim(v_sources)
    build_sim_test("006")
    # run_sim()
    # check()


if __name__ == "__main__":
    main()
