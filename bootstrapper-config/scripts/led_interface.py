"""Interfaces for representing LED lights animations."""

# Copyright 2024 Fictionlab sp. z o.o.
# All rights reserved.

import copy
import time
from enum import Enum, auto
from serial import Serial
from threading import Event, Lock, Thread
from typing import Optional


class LEDManager:
    """Representing and managing animation for single LED

    Attributes
    ----------
    stages : list[int]
        List of integers representing consecutive brightness values
        of the LED light to be set (animation)
    durations : list[float]
        List of floats representing the duration of each stage (in seconds).
    loop : bool
        Flag specyfing if the animation should be looped at the end.
    name : str
        Name of the animation (needed only for more information if an error occurs)
    """

    def __init__(
        self,
        stages: list[int],
        durations: list[float],
        loop: bool = True,
        name: str = "",
    ):
        assert len(stages) == len(
            durations
        ), f"{name}: Number of steps not equal number of durations"

        self.stages = stages
        self.durations = durations

        self.loop = loop

    def init_anim(self, frequency: float) -> None:
        """Function used to reset the animation and get the stages durations in frames.

        Parameters
        ----------
        frequency : float
            Frequency of the serial writing loop.
        """
        # used as an iterator for all stages of animation
        self.current_stage = 0
        # used for counting the frames of current animation stage
        self.current_stage_counter = 0

        self.ended = False

        frames_per_stage = [int(i * frequency) for i in self.durations]
        self.setup = list(zip(self.stages, frames_per_stage))

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

        value, frames = self.setup[self.current_stage]

        # still the same stage
        if self.current_stage_counter < frames - 1:
            # -1 in the condition as first tick of the stage happens during the stage change
            self.current_stage_counter += 1
            return value

        # stage ended, switching to next
        self.current_stage += 1
        self.current_stage_counter = 0

        if self.loop:
            # looping the animation
            self.current_stage %= len(self.stages)
        elif self.current_stage >= len(self.stages):
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
        self.led2_anim = led2 if led2 else copy.deepcopy(led1)

    def init_animation(self, frequency: float):
        self.led1_anim.init_anim(frequency)
        self.led2_anim.init_anim(frequency)

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


class AnimationType(Enum):
    STARTING = auto()
    FLASHING = auto()
    FINISH = auto()
    OFF = auto()
    ERROR = auto()


ANIMATIONS = {
    AnimationType.STARTING: Animation(
        LEDManager(stages=[10, 0], durations=[0.5, 0.5], name="STARTING_LEFT"),
        LEDManager(stages=[0, 10], durations=[0.5, 0.5], name="STARTING_RIGHT"),
    ),
    AnimationType.FLASHING: Animation(
        LEDManager(
            stages=list(range(0, 25, 1)) + list(range(25, 0, -1)),
            durations=[0.04] * 50,
            name="FLASHING",
        )
    ),
    AnimationType.FINISH: Animation(
        LEDManager(stages=[10, 0, 10, 0], durations=[0.1, 0.1, 0.1, 0.7], name="FINISH")
    ),
    AnimationType.OFF: Animation(LEDManager(stages=[0], durations=[1], name="OFF")),
    AnimationType.ERROR: Animation(LEDManager(stages=[5], durations=[1], name="ERROR")),
}


class AnimationManager(Thread):
    def __init__(self, initial_state=AnimationType.OFF, timer_period=0.01, serial=None):
        super().__init__()
        self.frequency = 1 / timer_period
        self.mutex = Lock()
        self._stop_event = Event()
        self.set_animation(initial_state)
        self.serial = serial

    def set_animation(self, new_anim_type) -> None:
        """Change animation dynamically.

        Parameters
        ----------
        new_anim_type : AnimationType
            One of predefined animation types.
        """
        with self.mutex:
            self.current_animation = ANIMATIONS[new_anim_type]
            self.current_animation.init_animation(self.frequency)

    def next_value(self) -> tuple[int, int]:
        """Get the next LED brightness value

        Returns
        -------
        tuple[int, int]
            The brightness values of the LED lights to be set.
        """
        with self.mutex:
            return self.current_animation.next_values()
        
    def run(self):
        while not self._stop_event.is_set():
            led1, led2 = self.next_value()
            self.serial.write(f"$LED:{led1},0,0,0,{led2}\r\n".encode("utf-8"))
            time.sleep(1/self.frequency)

    def stop(self):
        self._stop_event.set()

