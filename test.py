import os
import subprocess
import shutil
import glob
from pathlib import Path

current_dir = os.getcwd()

if current_dir.endswith("testspace"):
    PWD = os.path.join(current_dir, "../")
else:
    PWD = current_dir

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
        command, shell=True, cwd=cwd, capture_output=True, text=True, errors="replace"
    )
    if result.returncode != 0:
        print(f"Error running command: {command}")
        print(f"Output: {result.stdout}")
        print(f"Error: {result.stderr}")
        exit(1)
    if result.stdout != "":
        print(result.stdout)


def run_command_OUT(command, cwd=None):
    result = subprocess.run(
        command, shell=True, cwd=cwd, capture_output=True, text=True, errors="replace"
    )
    if result.returncode != 0:
        print(f"Error running command: {command}")
        print(f"Output: {result.stdout}")
        print(f"Error: {result.stderr}")
        exit(1)
    if result.stdout != "":
        print(result.stdout)
    with open(os.path.join(TESTSPACE_DIR, "my.ans"), "w") as f:
        f.write(result.stdout)


def testcases():
    run_command("make", cwd=TESTCASE_DIR)


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
    test_in = os.path.join(SIM_TESTCASE_DIR, f"*{name}*.in")

    for src, dst in [
        (test_c, "test.c"),
        (test_data, "test.data"),
        (test_dump, "test.dump"),
        (test_ans, "test.ans"),
        (test_in, "test.in"),
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


def run_fpga():
    fpga_device = "/dev/ttyUSB1"
    fpga_run_mode = "-T"  # or '-I'

    test_in = os.path.join(TESTSPACE_DIR, "test.in")
    test_data = os.path.join(TESTSPACE_DIR, "test.data")
    fpga_script = os.path.join(PWD, "fpga", "fpga.elf")

    if os.path.exists(test_in):
        command = (
            f"wsl {fpga_script} {test_data} {test_in} {fpga_device} {fpga_run_mode}"
        )
    else:
        command = f"wsl {fpga_script} {test_data} {fpga_device} {fpga_run_mode}"

    command = command.replace("\\", "/")
    command = command.replace("D:/", "/mnt/d/")
    run_command_OUT(command, cwd=TESTSPACE_DIR)


def print_fpga_cmd():
    fpga_device = "/dev/ttyUSB1"
    fpga_run_mode = "-T"  # or '-I'

    test_in = os.path.join(TESTSPACE_DIR, "test.in")
    test_data = os.path.join(TESTSPACE_DIR, "test.data")
    fpga_script = os.path.join(PWD, "fpga", "fpga.elf")

    if os.path.exists(test_in):
        command = (
            f"wsl {fpga_script} {test_data} {test_in} {fpga_device} {fpga_run_mode}"
        )
    else:
        command = f"wsl {fpga_script} {test_data} {fpga_device} {fpga_run_mode}"

    command = command.replace("\\", "/")
    command = command.replace("D:/", "/mnt/d/")
    print("command = ", command)


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
            print("\033[92mPASS\033[0m")
        else:
            print("\033[91mFAIL\033[0m")


import time


def main():
    v_sources = find_v_sources(SRC_DIR)

    build_sim(v_sources)
    build_sim_test("006")
    start_time = time.time()  # 记录开始时间
    run_sim()
    end_time = time.time()  # 记录结束时间
    check()

    elapsed_time = end_time - start_time  # 计算运行时间
    print(f"运行时间: {elapsed_time:.2f} 秒")


def gen_bit():
    gen_bit_path = "gen.bit"
    if os.path.exists(gen_bit_path):
        os.remove(gen_bit_path)
        print(f"Deleted existing {gen_bit_path}")
    # print("Start to gen bit")
    # command = "vivado -nojournal -nolog -mode batch -script .\script\genbit.tcl"
    # run_command(command, cwd=PWD)


def load():
    print("Start to close port")
    command = "usbipd detach --busid 2-3"
    run_command(command, cwd=PWD)
    print("Start to load bit")
    command = "vivado -nojournal -nolog -mode batch -script .\script\program.tcl -tclarg .\gen.bit"
    run_command(command, cwd=PWD)
    print("Start to connect to port")
    command = "usbipd attach --wsl --busid 2-3"
    run_command(command, cwd=PWD)


testlist = [
    "array_test1",
    "array_test2",
    "expr",
    "gcd",
    "lvalue",
    "multiarray",
    "pi",
    "qsort",
    # "testsleep",
    "basicopt",
    "bulgarian",
    "manyarguments",
    "hanoi",
    "tak",
    "uartboom",
    # "heart"
]

testlist2 = [
    "queens",
    "magic",
    "superloop",
    "statement_test",
]


def test1():
    load()
    time.sleep(1)
    for test in testlist:
        print("Start to run test: " + test)
        build_fpga_test(test)
        start_time = time.time()  # 记录开始时间
        run_fpga()
        end_time = time.time()  # 记录结束时间
        check()

        elapsed_time = end_time - start_time  # 计算运行时间
        print(f"运行时间: {elapsed_time:.2f} 秒")


def test2():
    for test in testlist2:
        load()
        time.sleep(1)
        print("Start to run test: " + test)
        build_fpga_test(test)
        start_time = time.time()  # 记录开始时间
        run_fpga()
        end_time = time.time()  # 记录结束时间
        check()

        elapsed_time = end_time - start_time  # 计算运行时间
        print(f"运行时间: {elapsed_time:.2f} 秒")


if __name__ == "__main__":
    # main()

    # gen_bit()

    # load()

    test1()

    test2()

    build_fpga_test("heart")
    print_fpga_cmd()
