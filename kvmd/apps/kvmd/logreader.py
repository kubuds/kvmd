# ========================================================================== #
#                                                                            #
#    KVMD - The main PiKVM daemon.                                           #
#                                                                            #
#    Copyright (C) 2018-2024  Maxim Devaev <mdevaev@gmail.com>               #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.  #
#                                                                            #
# ========================================================================== #


import re
import asyncio
import time

from typing import AsyncGenerator

# =====
class LogReader:
    async def poll_log(self, seek: int, follow: bool) -> AsyncGenerator[dict, None]:
        # TODO: maybe a configurable log file path?
        entry = {
            "__REALTIME_TIMESTAMP": "TODO___REALTIME_TIMESTAMP",
            "_SYSTEMD_UNIT": "TODO__SYSTEMD_UNIT",
            "MESSAGE": "TODO_MESSAGE",
        }
        yield self.__entry_to_record(entry)

    def __entry_to_record(self, entry: dict) -> dict[str, dict]:
        return {
            "dt": entry["__REALTIME_TIMESTAMP"],
            "service": entry["_SYSTEMD_UNIT"],
            "msg": entry["MESSAGE"].rstrip(),
        }
