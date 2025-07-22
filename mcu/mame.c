
// baswed on https://github.com/TheHpman/mame/blob/master/src/devices/bus/megadrive/rom.cpp

#include "appmain.h"

#define PPM_DATA_START_ADDR     0x10000	// base sdram unpack address
#define PPM_MAX_VRAM_SLOTS      64
#define PPM_OBJECTS_COUNT       64
#define PPM_MAX_OBJ_BLOCKS      32

void ppm_vram_reset_blocks(uint16_t last_block);
void ppm_close_sprite_table();
void ppm_obj_render(uint16_t obj_slot);
uint16_t ppm_vram_load_block(uint16_t num);
uint16_t ppm_vram_find_block(uint16_t num);

ppm_vram_slot ppm_vram_slots[PPM_MAX_VRAM_SLOTS];
uint8_t ppm_drawList[PPM_OBJECTS_COUNT]; // contains slot #
uint8_t *ppm_drawListPtr;
uint16_t ppm_vram_max_slot;

uint32_t *ppm_bgm_tracks_offsets;
uint32_t ppm_bgm_tracks_base_addr;
uint32_t ppm_bgm_unpack_addr;

uint32_t ppm_unk_data_addr;
uint32_t ppm_unk_data2_addr;

ppm_sfx *ppm_sfx_data;
uint32_t ppm_sfx_base_addr;

uint32_t ppm_anim_data_base_addr;
uint32_t *ppm_anim_data;
uint16_t ppm_anim_max_index[256];

uint32_t *ppm_gfx_blocks_offsets;
uint32_t ppm_gfx_blocks_base_addr;
uint32_t ppm_max_gfx_block;

uint16_t ppm_block_unpack_addr;
ppm_obj ppm_object_handles[PPM_OBJECTS_COUNT]; // matching intf objs
uint8_t ppm_scale_stamp[64][32];

void ppm_init_mame() {

    ppm_drawListPtr = ppm_drawList;
}

void ppm_vram_reset_blocks(uint16_t last_block) {

    ppm_vram_slot *slot = &ppm_vram_slots[last_block];

    for (uint16_t i = last_block; i < PPM_MAX_VRAM_SLOTS; slot++, i++) {
        slot->block_num = 0;
        slot->usage = 0;
        slot->age = 0;
    }
}

void ppm_obj_reset() {

    ppm_vram_reset_blocks(0);

    memset((void *) ppmio.ramdp->obj_data, 0, sizeof (ppmio.ramdp->obj_data));
    ppm_drawListPtr = ppm_drawList;
}

void ppm_vram_set_budget(uint16_t blocks) {
    // temp failsafe
    if (blocks > 0x35) {
        printf("Allocation error (0x%x blocks)\n", blocks);
        blocks = 0x35;
    }
    ppm_vram_reset_blocks((ppm_vram_max_slot = blocks));
}

void ppm_setup_data(uint32_t bgm_file, uint32_t unk1_file, uint32_t smp_file, uint32_t unk2_file, uint32_t sfx_file, uint32_t anm_file, uint32_t blk_file) {

    uint32_t unpack_addr = PPM_DATA_START_ADDR;

    // setup misc data (unpack some of thoses to sdram):
    // bgm data
    printf("BGM data: 0x%x\n", bgm_file);
    ppm_bgm_tracks_base_addr = bgm_file;
    ppm_bgm_tracks_offsets = (uint32_t *) & ppmio.flash[bgm_file]; // m_rom[bgm_file / 2];
    // ?? data
    printf("uk1 data: 0x%x > 0x%x\n", unk1_file, unpack_addr);
    ppm_unk_data_addr = unpack_addr;
    unpack_addr += ppm_unpack(unk1_file, unpack_addr);
    unpack_addr++;
    unpack_addr &= ~1;


    //++unpack_addr &= 0xfffffffeu; // word align
    // samples data (WavPack file)
    printf("SMP data: 0x%x >  0x%x\n", smp_file, unpack_addr);
    // unpacked data is about 1.4MB
    // ?? data
    printf("uk2 data: 0x%x > 0x%x\n", unk2_file, unpack_addr);
    ppm_unk_data2_addr = unpack_addr;
    unpack_addr += ppm_unpack(unk2_file, unpack_addr);
    //++unpack_addr &= 0xfffffffeu; // word align
    unpack_addr++;
    unpack_addr &= ~1;


    // sfx data
    printf("SFX data: 0x%x\n", sfx_file);
    ppm_sfx_base_addr = sfx_file;
    ppm_sfx_data = (ppm_sfx *) & ppmio.flash[sfx_file]; //m_rom[sfx_file / 2];
    ppm_sfx *fx = &ppm_sfx_data[1]; 

    for (int x = 1; x <= ppm_sfx_data[0].length; fx++, x++) {
        //printf("\tSFX 0x%x: 0x%x / 0x%x / 0x%x\n", x, swapshorts(fx->offset), fx->attributes, fx->length);
    }
    // animation data
    printf("ANM data: 0x%x > 0x%x\n", anm_file, unpack_addr);
    ppm_anim_data_base_addr = unpack_addr;
    unpack_addr += ppm_unpack(anm_file, unpack_addr);
    //++unpack_addr &= 0xfffffffeu; // word align
    unpack_addr++;
    unpack_addr &= ~1;


    ppm_anim_data = (uint32_t *) & ppmio.sdram[ppm_anim_data_base_addr]; // ppm_sdram[ppm_anim_data_base_addr / 2];
    printf("anim data for 0x%x objs\n", ppm_anim_data[0]);

    for (uint16_t x = 1; x <= ppm_anim_data[0]; x++) {

        uint32_t anim_offset = ppm_anim_data[x];
        uint16_t anim_count = 0;

        //printf("offset: %x\n", anim_offset);

        while (ppm_anim_data[anim_count + (anim_offset / 4)] != 0xffffffffu) {
            anim_count++;
        }
        ppm_anim_max_index[x - 1] = anim_count - 1;
        //printf("\tobj 0x%x (0x%x): %i anims\n", x, anim_offset, anim_count);

        if (anim_offset & 0x3) {
            printf("(unaligned pointers)\n");
        }
    }

    // blocks data
    printf("BLK data: 0x%x\n", blk_file);
    ppm_gfx_blocks_base_addr = blk_file;
    ppm_gfx_blocks_offsets = (uint32_t *) & ppmio.flash[blk_file]; //m_rom[blk_file / 2];
    ppm_max_gfx_block = swapshorts(ppm_gfx_blocks_offsets[0]) - 1;
    printf("blocks addr: %x, count: %i\n", ppm_gfx_blocks_base_addr, swapshorts(ppm_gfx_blocks_offsets[0]));

    printf("unpack addr finish: 0x%x / free: 0x%x\n", unpack_addr, 0x200000 - unpack_addr);
    ppm_bgm_unpack_addr = unpack_addr;

}

u32 swapshorts(u32 val) {

    return (val >> 16) | (val << 16);
}

uint32_t ppm_unpack(uint32_t source_addr, uint32_t dest_addr) {

    return ppm_unpack_scal(source_addr, dest_addr, 0);
}

uint32_t ppm_unpack_scal(uint32_t source_addr, uint32_t dest_addr, u8 is_scaling_stamp) {

    // packed data is byte width, ^1 on all addresses to fix endian mumbo jumbo
    uint8_t code, count, data_byte;
    uint32_t copy_addr;
    uint32_t initial_dest_addr = dest_addr;
    uint8_t *packed_data = (uint8_t *) ppmio.flash; // m_rom;
    uint8_t *unpacked_data = is_scaling_stamp ? (uint8_t *) ppm_scale_stamp : (uint8_t *) ppmio.sdram; // ppm_sdram;

    uint16_t copy_size, literal_size;

    //printf("unpack format: %x\n", packed_data[source_addr]);

    switch (packed_data[source_addr++ ^ 1]) {

        case 0x80:

            while ((code = packed_data[source_addr++ ^ 1])) {

                switch (count = code & 0x3f, code >> 6) {
                    case 0:
                        while (count--)
                            unpacked_data[dest_addr++ ^ 1] = packed_data[source_addr++ ^ 1];
                        break;
                    case 1:
                        data_byte = packed_data[source_addr++ ^ 1];
                        while (count--)
                            unpacked_data[dest_addr++ ^ 1] = data_byte;
                        break;
                    case 2:
                        copy_addr = dest_addr - packed_data[source_addr++ ^ 1];
                        while (count--)
                            unpacked_data[dest_addr++ ^ 1] = unpacked_data[copy_addr++ ^ 1];
                        break;
                    case 3:
                        while (count--)
                            unpacked_data[dest_addr++ ^ 1] = 0;
                        break;
                }
            }
            break;

        case 0x81:

            while ((code = packed_data[source_addr++ ^ 1]) != 0x11) // unconfirmed end code
            {
                switch (code >> 4) {
                    case 0:
                        copy_size = 0;
                        literal_size = code ? (3 + (code & 0x1f)) : (0x12 + packed_data[source_addr++ ^ 1]);
                        break;
                    case 1:
                        if ((copy_size = 2 + (code & 0x7)) == 2)
                            copy_size = 9 + packed_data[source_addr++ ^ 1];
                        literal_size = packed_data[source_addr ^ 1] & 0x3;
                        copy_addr = dest_addr - 0x4000 - (((packed_data[(source_addr + 1) ^ 1] << 8) + packed_data[source_addr ^ 1]) >> 2);
                        source_addr += 2;
                        break;
                    case 2:
                    case 3:
                        if ((copy_size = (code & 0x1f)))
                            copy_size += 2;
                        else {
                            copy_size = 0x21;
                            while (!packed_data[source_addr++ ^ 1])
                                copy_size += 0xff;
                            copy_size += packed_data[(source_addr - 1) ^ 1];
                        }
                        literal_size = packed_data[source_addr ^ 1] & 0x3;
                        copy_addr = dest_addr - 1 - (((packed_data[(source_addr + 1) ^ 1] << 8) + packed_data[source_addr ^ 1]) >> 2);
                        source_addr += 2;
                        break;
                    default:
                        copy_size = (code >> 5) + 1;
                        literal_size = code & 0x3;
                        copy_addr = dest_addr - 1 - (((code >> 2) & 0x7) + (packed_data[source_addr ^ 1] << 3));
                        source_addr++;
                        break;
                }
                while (copy_size--)
                    unpacked_data[dest_addr++ ^ 1] = unpacked_data[copy_addr++ ^ 1];
                while (literal_size--)
                    unpacked_data[dest_addr++ ^ 1] = packed_data[source_addr++ ^ 1];
            }
            break;

        default:
            printf("unknown packer format, wrong address? (0x%x) %x\n", source_addr - 1, ppmio.ramdp->reg_cmd);
            break;
    }

    return dest_addr - initial_dest_addr;
}

void ppm_obj_add(uint8_t num) {
    *ppm_drawListPtr++ = num;
}

void ppm_obj_frame_start() {

    ppm_drawListPtr = ppm_drawList;

    // all blocks unused
    ppm_vram_slot *slot = ppm_vram_slots;

    for (uint16_t x = 0; x < PPM_MAX_VRAM_SLOTS; slot++, x++) {
        slot->usage = 0;
    }
}

void ppm_obj_frame_end() {

    ppm_block_unpack_addr = 0x9000;
    ppmio.ramdp->dma_remaining = ppmio.ramdp->dma_budget - ppmio.ramdp->dma_total;

    //printf("dma: %i\n", ppmio.ramdp->dma_remaining);

    uint8_t *ptr = ppm_drawList;

    while (ptr != ppm_drawListPtr) {
        ppm_obj_render(*ptr++);
    }

    ppm_vram_slot *slot = ppm_vram_slots;

    for (uint16_t x = 0; x < PPM_MAX_VRAM_SLOTS; slot++, x++) {

        if (!slot->usage) {
            slot->age++;
        }
    }

    ppm_close_sprite_table();
    //ppm_sdram_pointer = &ppm_sdram[0x9000 / 2];
    FPGAIO->sdram_ptr = 0x9000;
}

void ppm_close_sprite_table() {

    ppm_sat_item *sat_entry = &ppmio.ramdp->sat_data[ppmio.ramdp->sat_count];

    if (!ppmio.ramdp->sat_count) {
        sat_entry->posY = 0x10;
        sat_entry->sizeNext = 0;
        sat_entry->attrs = 0;
        sat_entry->posX = 0x10;
        ppmio.ramdp->sat_count++;
    } else {
        (--sat_entry)->sizeNext &= 0xff00;
    }

    ppm_dma_cmd *dma_entry = &ppmio.ramdp->dma_cmd[ppmio.ramdp->dma_cmd_count++];
    dma_entry->autoinc = 0x8f02;

    uint16_t word_size = ppmio.ramdp->sat_count * (sizeof (ppm_sat_item) / 2);
    dma_entry->lenH = 0x9400 + (word_size >> 8);
    dma_entry->lenL = 0x9300 + (word_size & 0xff);

    uint32_t sat_addr = offsetof(ppm_ramdp, sat_data) / 2;
    dma_entry->srcH = 0x9700 + ((sat_addr >> 16) & 0xff);
    dma_entry->srcM = 0x9600 + ((sat_addr >> 8) & 0xff);
    dma_entry->srcL = 0x9500 + (sat_addr & 0xff);

    // xfer to SAT location in VRAM (0xf000)
    dma_entry->cmdH = 0x7000;
    dma_entry->cmdL = 0x0083;
}

void ppm_obj_render(uint16_t obj_slot) {

    ppm_intf_obj *intf_obj = &ppmio.ramdp->obj_data[obj_slot]; // interface obj
    ppm_obj *handle = &ppm_object_handles[obj_slot]; // internal handle

    if ((intf_obj->anim & 0xff) > ppm_anim_max_index[intf_obj->objID & 0xff]) {
        printf("anim over for ID %x: 0x%x/0x%x\n", intf_obj->objID & 0xff, intf_obj->anim & 0xff, ppm_anim_max_index[intf_obj->objID & 0xff]);
        return;
    }

    uint32_t offset, data_offset;
    uint32_t previous_offset = handle->anim_offset;
    uint16_t previous_counter = handle->counter;

    //	printf("Slot 0x%02x (ID 0x%04x): ", obj_slot, intf_obj->objID);

    // set / update animation
    if ((intf_obj->objID & 0x8000) || (intf_obj->anim != handle->crtAnim) || (intf_obj->animCounter != handle->counter)) {
        // fresh obj?
        if (intf_obj->objID & 0x8000) {
            previous_offset = 0, previous_counter = 1;
        }

        offset = ppm_anim_data[(intf_obj->objID & 0xff) + 1]; // obj offset
        offset = ppm_anim_data[(offset >> 2) + (intf_obj->anim & 0xff)]; // anim offset
        data_offset = ppm_anim_data[offset >> 2] & 0xffffffu; // data offset

        handle->anim_offset = offset;
        handle->crtAnim = intf_obj->anim;
        handle->counter = intf_obj->animCounter;
    } else {
        // move to next frame

        // get current offset (previous frame)
        if (!(offset = handle->anim_offset))
            return;
        // read data pointer
        data_offset = ppm_anim_data[offset >> 2];

        if (data_offset & 0x80000000u) {
            // previous frame was not last, just move to next
            offset += 4;
        } else {
            // anim is over, do we have fallback anim?
            if (intf_obj->nextAnim != 0xffff) {
                // yes, switch anims
                intf_obj->anim = intf_obj->nextAnim;
                intf_obj->nextAnim = 0xffff; // unverified
                ppm_obj_render(obj_slot);
                return;
            } else {
                // no, take anim loop
                offset = ppm_anim_data[(offset + 4) >> 2] & 0xffffffu;
            }
        }

        if (!(handle->anim_offset = offset)) {
            // store offset
            return;
        }

        data_offset = ppm_anim_data[offset >> 2] & 0xffffffu;
        intf_obj->animCounter++;
        handle->counter++;
    }

    // render sprite to SAT
    // > data might not be 4 bytes aligned, access via ppm_sdram <
    ppm_spr_data_hdr *spr_info = (ppm_spr_data_hdr *) & ppmio.sdram[(ppm_anim_data_base_addr + data_offset)];
    ppm_sat_item *satEntry = &ppmio.ramdp->sat_data[ppmio.ramdp->sat_count];
    int16_t posX = intf_obj->posX;
    int16_t posY = intf_obj->posY;

    bool blocks_available = true;
    // load new spr data
    ppm_spr_data *spr_data = &spr_info->sprites[0];

    for (uint16_t x = 0; x < spr_info->count; spr_data++, x++) {

        if (!spr_data->blockNum) {
            continue;
        }

        if (!ppm_vram_load_block(spr_data->blockNum)) {
            blocks_available = false;
            // break; need to iterate all to keep resevations?
        }
    }

    if (!blocks_available) {

        if (previous_offset) {
            // restore offset/counter
            handle->anim_offset = previous_offset;
            handle->counter = previous_counter;
            intf_obj->animCounter = previous_counter;
            data_offset = ppm_anim_data[previous_offset >> 2] & 0xffffff;
            spr_info = (ppm_spr_data_hdr *) & ppmio.sdram[(ppm_anim_data_base_addr + data_offset)];

        } else {
            return;
        }
    }

    spr_data = &spr_info->sprites[0];


    for (uint16_t x = 0; x < spr_info->count; spr_data++, x++) {

        posX += (intf_obj->attrs & 0x0800) ? spr_data->flipPosX : spr_data->posX;
        posY += spr_data->posY;

        if (!spr_data->blockNum) {
            continue;
        }

        // clipping
        if ((posX >= 320 + 128) ||
                (posY >= 240 + 128) ||
                (posX < 128 - ((((spr_data->size >> 2) & 0x3) + 1) * 8)) ||
                (posY < 128 - (((spr_data->size & 0x3) + 1) * 8))) {
            continue;
        }

        ppmio.ramdp->sat_count++;
        satEntry->posX = posX & 0x1ff;
        satEntry->posY = posY & 0x3ff;
        satEntry->sizeNext = ((spr_data->size & 0xf) << 8) + (ppmio.ramdp->sat_count & 0xff);
        satEntry->attrs = ((spr_data->attrs & 0xf8) << 8) ^ intf_obj->attrs ^ (ppm_vram_find_block(spr_data->blockNum) + spr_data->offset); // whole attr word?
        satEntry++;
    }

    intf_obj->objID &= 0x7fff;
}

uint16_t ppm_vram_load_block(uint16_t num) {

    if (!num) {
        return 0;
    }

    // is block already in VRAM?
    ppm_vram_slot *slot = ppm_vram_slots;

    for (uint16_t x = 0; x < ppm_vram_max_slot; slot++, x++) {

        if (slot->block_num == num) {
            slot->usage++;
            slot->age = 0;
            return ((x + (x <= 0x30 ? 1 : 0x4b)) << 4);
        }
    }

    // enough DMA budget?
    if (ppmio.ramdp->dma_remaining < 0x110) {
        return 0;
    }


    // find oldest slot to load into
    uint32_t max_age = 0;
    uint16_t block_index = 0xffff;
    slot = ppm_vram_slots;

    for (uint16_t x = 0; x < ppm_vram_max_slot; slot++, x++)
        if ((!slot->usage) && (slot->age > max_age)) {
            max_age = slot->age;
            block_index = x;
        }

    // no slot available?
    if (block_index == 0xffff) {
        return 0;
    }

    // found slot & have budget, unpack and DMA the block
    slot = &ppm_vram_slots[block_index];
    slot->block_num = num;
    slot->usage++;
    slot->age = 0;

    ppm_unpack(ppm_block_addr(num), ppm_block_unpack_addr);
    ppm_block_unpack_addr += 0x200;

    ppm_dma_cmd *dma_entry = &ppmio.ramdp->dma_cmd[ppmio.ramdp->dma_cmd_count++];

    ppmio.ramdp->dma_remaining -= 0x110;
    dma_entry->autoinc = 0x8f02;
    dma_entry->lenH = 0x9401;
    dma_entry->lenL = 0x9300; // 0x200 words size
    dma_entry->srcH = 0x9700;
    dma_entry->srcM = 0x9660;
    dma_entry->srcL = 0x9500; // 0xc000 source

    block_index += (block_index <= 0x30 ? 1 : 0x4b); // translate index
    uint32_t command = (((block_index << 25) | (block_index >> 5)) & 0x3fff0003) | 0x40000080;

    dma_entry->cmdH = command >> 16;
    dma_entry->cmdL = command;

    //printf("vram %x %x\n", block_index, command);

    return (block_index << 4);
}

u32 ppm_block_addr(u32 num) {

    return ppm_gfx_blocks_base_addr + swapshorts(ppm_gfx_blocks_offsets[(num)]);
}

u32 ppm_bgm_addr(u32 num) {

    return ppm_bgm_tracks_base_addr + swapshorts(ppm_bgm_tracks_offsets[(num)]);
}

uint16_t ppm_vram_find_block(uint16_t num) { // return tile index

    ppm_vram_slot *slot = ppm_vram_slots;

    for (uint16_t x = 0; x < ppm_vram_max_slot; slot++, x++) {

        if (slot->block_num == num) {

            return ((x + (x <= 0x30 ? 1 : 0x4b)) << 4);
        }
    }
    return 0;
}

void ppm_stamp_rescale(uint16_t window_start, uint16_t window_end, uint16_t factor, uint16_t stamp_offset) {

    // prepare temp buffer
    uint8_t scaled_stamp[128][32];

    memset(scaled_stamp, 0, sizeof (scaled_stamp));

    // scale the stamp in temp buffer
    float offset = (float) stamp_offset;
    float adder = (float) factor / 64;
    for (uint16_t y = window_start; y < window_end; offset += adder, y++)
        memcpy(&scaled_stamp[y][0], &ppm_scale_stamp[(int) offset][0], 32);

    // translate data: 128*32px block, as 4*32 px strips
    // layout is weird because... reasons?
    for (uint16_t s = 0; s < 32; s++) // 4px strips
    {
        // uint16_t clmn = ((s << 4) & 0xffe0) + (s & 1 ? 0x200 : 0);
        uint16_t clmn = ((s & 0xfe) << 4) + ((s & 1) << 9);
        for (uint16_t y = 0; y < 32; y++) {
            // 1 word contains 4 pixels
            ppmio.ramdp->scaling_buff[clmn + y] =
                    (((scaled_stamp[(s << 2) + 0][y ^ 1] & 0xf0) |
                    (scaled_stamp[(s << 2) + 1][y ^ 1] & 0x0f))
                    << 8) +
                    (((scaled_stamp[(s << 2) + 2][y ^ 1] & 0xf0) |
                    (scaled_stamp[(s << 2) + 3][y ^ 1] & 0x0f)));
        }
    }
}
