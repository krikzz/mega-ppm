/* 
 * File:   everdrive.h
 * Author: Igor
 *
 * Created on July 21, 2025, 11:13 PM
 */

#ifndef EVERDRIVE_H
#define	EVERDRIVE_H

void ed_fifo_flush();
u8 ed_cmd_rom_path(u8 *path, u8 path_type);
u8 ed_cmd_cd_mount(u8 *path);

#endif	/* EVERDRIVE_H */

