"""Interfaces for representing LED lights animations."""

# Copyright 2024 Fictionlab sp. z o.o.
# All rights reserved.

import time
import sys
from serial import Serial
from threading import Event, Lock
from typing import Optional

class LEDManager:
    """Representing and managing animation for single LED

    Attributes
    ----------
    stages : list[int]
        List of integers representing consecutive brightness values 
        of the LED light to be set (animation)
    durations : list[int]
        List of integers representing the duration of each stages (in 100ms).
    loop : bool
        Flag specyfing if the animation should be looped at the end.
    name : str
        Name of the animation (needed only for more information if an error occurs)
    """

    def __init__(
        self, stages: list[int], durations: list[int], loop: bool = True, name: str = ""
    ):
        assert len(stages) == len(
            durations
        ), f"{name}: Number of steps not equal number of durations"
        self.setup = list(zip(stages, durations))
        self.stages_num = len(stages)
        self.loop = loop
        # used as an iterator for all stages of animation
        self.current_stage = 0
        # used for counting the duration of current animation stage
        self.current_stage_counter = 0

        self.anim_duration = sum(durations)

        self.ended = False

    def next_value(self) -> int:
        """Function managing the animation process. Gets the next brightness value
        from the setup and loops the animation if needed.

        Returns
        -------
        int
            The brightness value of the LED light to be set.
            -1 determines that the animation has ended and is not looped.
        """
        if self.ended:
            return -1

        value, duration = self.setup[self.current_stage]

        # still the same stage
        if self.current_stage_counter < duration - 1:
            # -1 in the condition as first tick of the stage happens during the stage change
            self.current_stage_counter += 1
            return value

        # stage ended, switching to next
        self.current_stage = self.current_stage + 1

        if self.loop:
            # looping the animation
            self.current_stage %= self.stages_num
        elif self.current_stage >= self.stages_num:
            # ending the animation
            self.ended = True
            return -1

        value, _ = self.setup[self.current_stage]

        return value


class Animation:
    """Representing the light animation

    Attributes
    ----------
    led1 : LEDManager
        A LEDManager object representing desired animation for the first LED light
    led2 : Optional[LEDManager]
        A LEDManager object representing desired animation for the second LED light.
        If not set will be same as led1.
    """
    def __init__(self, led1: LEDManager, led2: Optional[LEDManager] = None):
        self.led1_anim = led1
        self.led2_anim = led2 if led2 else led1

    def next_values(self) -> tuple[int, int]:
        """Gets the next brightness values for both of the LED lights
        
        Returns
        -------
        tuple[int, int]
            The brightness values of the LED lights to be set.
        """
        val1 = self.led1_anim.next_value()
        val2 = self.led2_anim.next_value()

        val1 = max(val1, 0)
        val2 = max(val2, 0)

        return (val1, val2)


ANIMATIONS = {
    "FADE_IN_OUT": Animation(
        LEDManager(
            stages=[0, 5, 10, 15, 20, 25, 20, 15, 10, 5, 0],
            durations=[5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
            name="FADE_IN_OUT",
        )
    ),
    "FLASH": Animation(
        LEDManager(stages=[0, 10], durations=[5, 5], loop=False, name="FLASH")
    ),
    "OFF": Animation(LEDManager(stages=[0], durations=[1], name="OFF")),
    "ON": Animation(LEDManager(stages=[10], durations=[1], name="ON")),
}


class AnimationManager:
    def __init__(self, initial_state="OFF"):
        self.state = initial_state
        self.animation = ANIMATIONS[self.state]

    def set_state(self, new_state) -> None:
        """Change animation state dynamically.
        
        Parameters
        ----------
        new_state : str
            Name of the animation.
        """
        if new_state in ANIMATIONS:
            self.state = new_state
            self.animation, self.speeds = ANIMATIONS[new_state]
        else:
            print(f"Error: Unknown animation state '{new_state}'", file=sys.stderr)

    def next_value(self) -> tuple[int, int]:
        """Get the next LED brightness value
        
        Returns
        -------
        tuple[int, int]
            The brightness values of the LED lights to be set.
        """
        return self.animation.next_values()


def thread_loop(
    serial: Serial, stop: Event, manager: AnimationManager, manager_lock: Lock
):
    while not stop.is_set():
        with manager_lock:
            led1, led2 = manager.next_value()

        serial.write(f"$LED:{led1},0,0,0,{led2}\r\n".encode("utf-8"))
        time.sleep(0.1)

    serial.write("$LED:0,0,0,0,0\r\n".encode("utf-8"))
